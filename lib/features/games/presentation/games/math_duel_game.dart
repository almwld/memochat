import 'extended_game_engine.dart';

class MathDuelGame extends ExtendedGameEngine {
  MathDuelGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Math Duel',
    instruction: 'اختر نتيجة العملية',
    options: ["21","24","27","30"],
    correctIndex: 1,
  ));
}
