import 'package:audioplayers/audioplayers.dart';

class SoundManager {
  static final SoundManager _instance = SoundManager._internal();
  factory SoundManager() => _instance;
  SoundManager._internal();
  final AudioPlayer _callPlayer = AudioPlayer();
  final AudioPlayer _effectPlayer = AudioPlayer();
  bool _callPlaying = false;
  bool _effectPlaying = false;
  Future<void> _play(String asset,{double volume=1}) async { try { await _effectPlayer.stop(); await _effectPlayer.setReleaseMode(ReleaseMode.release); await _effectPlayer.setVolume(volume.clamp(0,1)); _effectPlaying=true; await _effectPlayer.play(AssetSource(asset)); } catch (_) { _effectPlaying=false; } }
  Future<void> playCallRingtone() async { try { await _callPlayer.stop(); await _callPlayer.setReleaseMode(ReleaseMode.loop); await _callPlayer.setVolume(.72); _callPlaying=true; await _callPlayer.play(AssetSource('audio/notification.mp3')); } catch (_) { _callPlaying=false; } }
  Future<void> playRingback() async { try { await _callPlayer.stop(); await _callPlayer.setReleaseMode(ReleaseMode.loop); await _callPlayer.setVolume(.72); _callPlaying=true; await _callPlayer.play(AssetSource('audio/ringback.mp3')); } catch (_) { _callPlaying=false; } }
  Future<void> playMessageSent()=>_play('audio/message_sent.mp3');
  Future<void> playMessageReceived()=>_play('audio/message_received.mp3');
  Future<void> playNotification()=>_play('audio/notification.mp3');
  Future<void> playCallStart()=>_play('audio/call_start.mp3');
  Future<void> playCallEnd()=>_play('audio/call_end.mp3');
  Future<void> playError()=>_play('audio/error.mp3');
  Future<void> playSuccess()=>_play('audio/success.mp3');
  Future<void> stopCallAudio() async { await _callPlayer.stop(); _callPlaying=false; }
  Future<void> stopAll() async { await stopCallAudio(); await _effectPlayer.stop(); _effectPlaying=false; }
  Future<void> stop()=>stopAll();
  bool get isPlaying=>_callPlaying||_effectPlaying;
}
