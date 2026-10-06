import 'package:audioplayers/audioplayers.dart';

class SoundManager {
  SoundManager._();
  static final SoundManager instance = SoundManager._();
  final AudioPlayer _player = AudioPlayer();
  Future<void> play(String asset) async { try { await _player.play(AssetSource(asset.startsWith('assets/') ? asset.substring(7) : asset)); } catch (_) {} }
  Future<void> stopCallAudio() async { try { await _player.stop(); } catch (_) {} }
  Future<void> stopAll() async { await stopCallAudio(); }
  Future<void> playCallRingtone() async { await play('audio/call_ringtone.wav'); }
  Future<void> playRingback() async { await play('audio/call_ringtone.wav'); }
  Future<void> dispose() => _player.dispose();
}
