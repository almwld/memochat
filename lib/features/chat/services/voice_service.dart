import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'chat_service.dart';
import '../../../core/media/media_transfer_engine.dart';

/// Records and plays chat voice messages.
/// Chat media is stored in Nextcloud; Firestore stores only message metadata/URL.
class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _media = MediaTransferEngine.instance;
  final ChatService _chatService = ChatService();

  String? _recordingPath;
  bool _isRecording = false;
  bool _startingRecording = false;
  bool _isPlaying = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  StreamSubscription<void>? _playerCompleteSubscription;

  Future<void> startRecording() async {
    if (_isRecording || _startingRecording) return;
    _startingRecording = true;
    try {
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
    } finally {
      _startingRecording = false;
    }
  }

  /// Stops recording and places the file in the durable media outbox.
  /// The worker performs Recorder → Outbox → Media → Firestore → FCM.
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
    try { await _recorder.stop(); } catch (_) {}

    final file = File(recordedPath);
    if (!await file.exists()) throw StateError('تعذر إنشاء ملف التسجيل الصوتي');
    if (await file.length() <= 0) throw StateError('ملف التسجيل الصوتي فارغ');
    if (_auth.currentUser == null) throw StateError('يجب تسجيل الدخول لإرسال رسالة صوتية');

    // Persist the recording before any network operation. Navigation, process
    // death, or a temporary network failure must not lose the voice message.
    final outboxId = await _media.enqueue(
      sourceFile: file,
      destination: MediaDestination.voice,
      type: 'audio',
      folder: 'audio',
      caption: '🎤 رسالة صوتية',
      preview: '🎤 رسالة صوتية',
      chatId: chatId,
      fileName: 'voice_' + DateTime.now().millisecondsSinceEpoch.toString() + '.m4a',
      mimeType: 'audio/mp4',
      audioDuration: _recordingDuration.inSeconds.toString(),
    );

    try { await file.delete(); } catch (_) {}
    _recordingPath = null;
    _recordingDuration = Duration.zero;
    return outboxId;
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
