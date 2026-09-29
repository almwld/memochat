import 'package:audioplayers/audioplayers.dart';

class SoundManager {
  SoundManager._();
  static final SoundManager instance = SoundManager._();
  final AudioPlayer _player = AudioPlayer();
  Future<void> play(String asset) async { try { await _player.play(AssetSource(asset.startsWith('assets/') ? asset.substring(7) : asset)); } catch (_) {} }
  Future<void> stop() async { try { await _player.stop(); } catch (_) {} }
  Future<void> dispose() => _player.dispose();
}
