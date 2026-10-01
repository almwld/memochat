import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';
import 'package:memochat/core/config/livekit_config.dart';

class LiveKitService {
  static final LiveKitService _instance = LiveKitService._internal();
  factory LiveKitService() => _instance;
  LiveKitService._internal();

  Room? _room;
  bool _isCameraEnabled = false;
  bool _isMicrophoneEnabled = false;
  bool _isSpeakerOn = true;
  bool _isConnected = false;
  bool _isFrontCamera = true;

  Room? get room => _room;
  bool get isConnected => _isConnected;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isCameraEnabled => _isCameraEnabled;
  bool get isMicrophoneEnabled => _isMicrophoneEnabled;

  Future<Map<String, dynamic>> _requestLiveKitToken({
    required String roomName,
    required String participantName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول قبل إجراء المكالمة');

    final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable(
      'createLiveKitToken',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 15),
      ),
    );

    final result = await callable.call(<String, dynamic>{
      'roomName': roomName,
      'participantName': participantName,
      'participantIdentity': user.uid,
    });

    final raw = result.data;
    if (raw is! Map) throw Exception('بيانات LiveKit غير صالحة');
    final payload = Map<String, dynamic>.from(raw);
    if (payload['success'] != true) {
      throw Exception(
        payload['message']?.toString() ?? 'تعذر إنشاء توكن LiveKit',
      );
    }
    final data = payload['data'];
    if (data is! Map) throw Exception('بيانات LiveKit غير صالحة');
    final value = Map<String, dynamic>.from(data);
    if ((value['token']?.toString() ?? '').isEmpty) {
      throw Exception('توكن LiveKit فارغ');
    }
    if ((value['url']?.toString() ?? '').isEmpty) {
      throw Exception('رابط LiveKit فارغ');
    }
    return value;
  }

  Future<Room> _connectWithRetry({
    required String url,
    required String token,
  }) async {
    const options = RoomOptions(
      adaptiveStream: true,
      dynacast: true,
      // Keep simulcast enabled so LiveKit can switch quality layers with
      // changing bandwidth instead of forcing a single fixed stream.
      defaultVideoPublishOptions: VideoPublishOptions(simulcast: true),
      defaultAudioPublishOptions: AudioPublishOptions(),
    );

    Object? lastError;
    for (var attempt = 1; attempt <= 3; attempt++) {
      final current = _room ??= Room(roomOptions: options);
      try {
        if (attempt > 1) {
          // Reuse the existing Room first so its lifecycle/listeners remain
          // intact in the normal retry path. Do not dispose between attempts.
          await current.disconnect();
        }
        debugPrint('LIVEKIT CONNECT attempt=$attempt/3');
        // On restrictive mobile networks the direct ICE candidates can fail
        // even though signaling is reachable. The final attempt forces TURN
        // relay, which is the reliable fallback for those networks.
        final connectOptions = attempt == 3
            ? const ConnectOptions(
                rtcConfiguration: RTCConfiguration(
                  iceTransportPolicy: RTCIceTransportPolicy.relay,
                ),
              )
            : null;
        await current
            .connect(
              url,
              token,
              connectOptions: connectOptions,
            )
            .timeout(const Duration(seconds: 25));
        return current;
      } catch (e, st) {
        lastError = e;
        _isConnected = false;
        debugPrint('LIVEKIT CONNECT attempt=$attempt/3 FAILED: $e');
        debugPrintStack(stackTrace: st);

        if (attempt == 2) {
          // Only after two failed attempts do we replace the Room. Callers
          // attach their listeners after connectRoom returns, so no existing
          // listeners are lost here.
          try {
            await current.disconnect();
          } catch (_) {}
          _room = Room();
        }
        if (attempt < 3) {
          await Future<void>.delayed(
            Duration(milliseconds: attempt == 1 ? 500 : 1000),
          );
        }
      }
    }
    throw lastError ?? StateError('تعذر الاتصال بخدمة LiveKit');
  }

  Future<Room> connectRoom({required String roomName, String? participantName}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('يجب تسجيل الدخول قبل إجراء المكالمة');
      final name = participantName?.trim().isNotEmpty == true
          ? participantName!.trim()
          : (user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : 'مستخدم');
      final tokenData = await _requestLiveKitToken(
        roomName: roomName,
        participantName: name,
      );
      final connectedRoom = await _connectWithRetry(
        url: tokenData['url'] as String,
        token: tokenData['token'] as String,
      );
      _room = connectedRoom;
      _isConnected = true;
      await enableMicrophone();
      await setSpeakerphone(true);
      return connectedRoom;
    } catch (e, st) {
      _isConnected = false;
      debugPrint('LIVEKIT CONNECT ERROR: $e');
      debugPrintStack(stackTrace: st);
      rethrow;
    }
  }

  Future<Room> startCall({required String roomName, String? callerName, bool isVideo = true}) async {
    final result = await connectRoom(roomName: roomName, participantName: callerName);
    if (!isVideo) return result;

    try {
      await enableCamera();

      // WebRTC may create the camera publication a moment after the
      // setCameraEnabled() future completes. Do not report a false camera
      // failure while the camera is actually starting.
      for (var attempt = 0; attempt < 10; attempt++) {
        final local = result.localParticipant;
        if (local != null) {
          for (final publication in local.trackPublications.values) {
            final candidate = publication.track;
            if (candidate is LocalVideoTrack &&
                publication.source == TrackSource.camera) {
              return result;
            }
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }

      throw StateError('تم تشغيل الكاميرا لكن لم يظهر مسار الفيديو');
    } catch (_) {
      // Never leave microphone/camera/WebRTC running when startup fails.
      try {
        await endCall();
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> enableCamera() async {
    final p = _room?.localParticipant;
    if (p == null) throw StateError('غرفة LiveKit غير متصلة');
    try {
      final publication = await p.setCameraEnabled(true);
      if (publication == null || publication.track == null) throw StateError('لم يتم إنشاء مسار فيديو للكاميرا');
      _isCameraEnabled = true;
      debugPrint('LIVEKIT CAMERA ENABLED sid=${publication.sid} source=${publication.source}');
    } catch (e) {
      _isCameraEnabled = false;
      debugPrint('LIVEKIT CAMERA ERROR: $e');
      rethrow;
    }
  }

  Future<void> enableMicrophone() async {
    final p = _room?.localParticipant;
    if (p == null) throw StateError('غرفة LiveKit غير متصلة');
    try {
      final publication = await p.setMicrophoneEnabled(true);
      if (publication == null) throw StateError('لم يتم نشر الميكروفون');
      _isMicrophoneEnabled = true;
    } catch (e) {
      _isMicrophoneEnabled = false;
      debugPrint('LIVEKIT MICROPHONE ERROR: $e');
      rethrow;
    }
  }

  Future<bool> toggleCamera() async {
    try {
      final p = _room?.localParticipant;
      if (p == null) return _isCameraEnabled;
      final state = !_isCameraEnabled;
      final publication = await p.setCameraEnabled(state);
      if (state && (publication == null || publication.track == null)) throw StateError('لم يتم نشر مسار الكاميرا');
      _isCameraEnabled = state;
      return state;
    } catch (e) {
      debugPrint('LIVEKIT CAMERA TOGGLE ERROR: $e');
      return _isCameraEnabled;
    }
  }

  Future<bool> toggleMicrophone() async {
    try {
      final p = _room?.localParticipant;
      if (p == null) return _isMicrophoneEnabled;
      final state = !_isMicrophoneEnabled;
      await p.setMicrophoneEnabled(state);
      _isMicrophoneEnabled = state;
      return state;
    } catch (e) {
      debugPrint('LIVEKIT MICROPHONE TOGGLE ERROR: $e');
      return _isMicrophoneEnabled;
    }
  }

  Future<void> switchCamera() async {
    final participant = _room?.localParticipant;
    if (participant == null) return;
    for (final publication in participant.trackPublications.values) {
      final track = publication.track;
      if (track is LocalVideoTrack) {
        _isFrontCamera = !_isFrontCamera;
        await track.setCameraPosition(_isFrontCamera ? CameraPosition.front : CameraPosition.back);
        return;
      }
    }
  }

  static const MethodChannel _callAudioChannel = MethodChannel('com.memo.app/call_audio');

  Future<void> setSpeakerphone(bool on) async {
    try {
      await Helper.setSpeakerphoneOn(on);
      _isSpeakerOn = on;
      try {
        await _callAudioChannel.invokeMethod('setSpeakerphone', {'enabled': on});
      } catch (e) {
        debugPrint('Native speaker route sync failed: $e');
      }
    } catch (e) {
      debugPrint('LiveKit speaker route failed: $e');
    }
  }

  Future<double> getCallVolume() async {
    try {
      final value = await _callAudioChannel.invokeMethod<num>('getCallVolume');
      return (value ?? 0.75).toDouble().clamp(0.0, 1.0);
    } catch (_) {
      return 0.75;
    }
  }

  Future<void> setCallVolume(double normalized) async {
    final value = normalized.clamp(0.0, 1.0);
    try {
      await _callAudioChannel.invokeMethod('setCallVolume', {'value': value});
    } catch (e) {
      debugPrint('Call volume update failed: $e');
    }
  }

  Future<void> endCall() async {
    try { await _room?.disconnect(); } finally {
      try { await Helper.setSpeakerphoneOn(false); } catch (_) {}
      try { await _callAudioChannel.invokeMethod('setSpeakerphone', {'enabled': false}); } catch (_) {}
      _room = null;
      _isConnected = false;
      _isCameraEnabled = false;
      _isMicrophoneEnabled = false;
      _isSpeakerOn = true;
      _isFrontCamera = true;
    }
  }

  void dispose() {
    _room?.disconnect();
    _room = null;
    _isConnected = false;
    _isCameraEnabled = false;
    _isMicrophoneEnabled = false;
    _isSpeakerOn = true;
    _isFrontCamera = true;
  }
}
