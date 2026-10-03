import 'extended_game_engine.dart';

class RiddleRushGame extends ExtendedGameEngine {
  RiddleRushGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Riddle Rush',
    instruction: 'حل اللغز بسرعة',
    options: ["الصدى","الظل","الوقت","المفتاح"],
    correctIndex: 0,
  ));
}
