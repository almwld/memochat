import 'extended_game_engine.dart';

class PatternTapGame extends ExtendedGameEngine {
  PatternTapGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Pattern Tap',
    instruction: 'اضغط النمط بالترتيب',
    options: ["1-2-3","2-3-1","3-1-2","1-3-2"],
    correctIndex: 0,
  ));
}
