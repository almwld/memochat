import '../classic_game_engine.dart';

class MemoryMatchGame extends ClassicGameEngine {
  MemoryMatchGame({super.key}) : super(config: const ClassicGameConfig(
    title: 'Memory Match',
    instruction: 'طابق الرموز المتشابهة',
    options: ["🍎","🚀","🍎","🎵"],
    correctIndex: 0,
  ));
}
