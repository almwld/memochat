import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

class RingtoneService {
  RingtoneService({AudioPlayer? player}) : _player = player ?? AudioPlayer();
  final AudioPlayer _player;
  bool _ringing = false;

  bool get isRinging => _ringing;

  Future<void> startIncomingCallRingtone({bool vibrate = true}) async {
    if (_ringing) return;
    _ringing = true;
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource('audio/call_ringtone.wav'));
    if (vibrate && await Vibration.hasVibrator()) {
      await Vibration.vibrate(pattern: [0, 700, 500], repeat: 0);
    }
  }

  Future<void> playMessageSound({bool vibrate = true}) async {
    if (_ringing) return;
    await _player.setReleaseMode(ReleaseMode.release);
    await _player.play(AssetSource('audio/message_tone.wav'));
    if (vibrate && await Vibration.hasVibrator()) await Vibration.vibrate(duration: 80);
  }

  Future<void> stopIncomingCallRingtone() async {
    _ringing = false;
    await _player.stop();
    if (await Vibration.hasVibrator()) await Vibration.cancel();
  }

  Future<void> stopAllSounds() => stopIncomingCallRingtone();

  Future<void> dispose() async {
    await stopAllSounds();
    await _player.dispose();
  }
}
