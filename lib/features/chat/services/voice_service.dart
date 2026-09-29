import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'nextcloud_service.dart';

/// Records and plays chat voice messages.
/// Chat media is stored in Nextcloud; Firestore stores only message metadata/URL.
class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NextcloudService _nextcloud = NextcloudService();

  String? _recordingPath;
  bool _isRecording = false;
  bool _isPlaying = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  StreamSubscription<void>? _playerCompleteSubscription;

  Future<bool> checkPermissions() => _recorder.hasPermission();

  Future<void> startRecording() async {
    if (_isRecording) return;
    if (!await checkPermissions()) throw Exception('لا توجد أذونات للتسجيل');

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _recordingPath = '${tempDir.path}/voice_$timestamp.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        bitRate: 128000,
      ),
      path: _recordingPath!,
    );

    _isRecording = true;
    _recordingDuration = Duration.zero;
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _recordingDuration += const Duration(seconds: 1);
    });
  }

  /// Stops recording, uploads to Nextcloud and creates the Firestore message.
  /// Throws on upload failure so the UI can keep the recording available/retry.
  Future<String?> stopRecording({
    required String chatId,
    VoidCallback? onProgress,
  }) async {
    if (!_isRecording && _recordingPath == null) return null;

    _recordingTimer?.cancel();
    _recordingTimer = null;
    _isRecording = false;

    final recordedPath = _recordingPath;
    if (recordedPath == null) return null;

    // Ensure the recorder has flushed the file before opening it.
    try {
      await _recorder.stop();
    } catch (_) {}

    final file = File(recordedPath);
    if (!await file.exists()) throw StateError('تعذر إنشاء ملف التسجيل الصوتي');

    final user = _auth.currentUser;
    if (user == null) throw StateError('يجب تسجيل الدخول لإرسال رسالة صوتية');

    await _nextcloud.loadConfig();
    final result = await _nextcloud.uploadFile(
      file: file,
      path: 'sehatak/chats/$chatId/audio',
      fileName: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
      onProgress: (sent, total) {
        onProgress?.call();
      },
    );

    if (!result.success || result.url == null || result.url!.isEmpty) {
      throw StateError(result.error ?? 'فشل رفع التسجيل الصوتي إلى Nextcloud');
    }

    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();

    final now = FieldValue.serverTimestamp();
    await messageRef.set({
      'text': '🎤 رسالة صوتية',
      'senderId': user.uid,
      'senderName': user.displayName ?? 'مستخدم',
      'timestamp': now,
      'type': 'audio',
      'audioUrl': result.url,
      'mediaUrl': result.url,
      'fileName': result.fileName,
      'duration': _recordingDuration.inSeconds,
      'isRead': false,
      'readAt': null,
    });

    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': '🎤 رسالة صوتية',
      'lastMessageTime': now,
      'updatedAt': now,
    });

    try {
      await file.delete();
    } catch (_) {}

    _recordingPath = null;
    _recordingDuration = Duration.zero;
    return result.url;
  }

  Future<void> cancelRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _isRecording = false;
    try {
      await _recorder.stop();
    } catch (_) {}

    final path = _recordingPath;
    _recordingPath = null;
    _recordingDuration = Duration.zero;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        try { await file.delete(); } catch (_) {}
      }
    }
  }

  Future<void> playAudio(String url, VoidCallback onComplete) async {
    await _playerCompleteSubscription?.cancel();
    try {
      _isPlaying = true;
      _playerCompleteSubscription = _player.onPlayerComplete.listen((_) {
        _isPlaying = false;
        onComplete();
      });
      await _player.play(UrlSource(url));
    } catch (_) {
      _isPlaying = false;
      rethrow;
    }
  }

  Future<void> stopAudio() async {
    await _player.stop();
    _isPlaying = false;
  }

  Duration get recordingDuration => _recordingDuration;
  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;

  Future<void> dispose() async {
    _recordingTimer?.cancel();
    await _playerCompleteSubscription?.cancel();
    await _player.dispose();
    _recorder.dispose();
  }
}
