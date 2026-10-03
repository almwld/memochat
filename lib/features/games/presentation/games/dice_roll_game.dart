import 'classic_game_engine.dart';

class DiceRollGame extends ClassicGameEngine {
  DiceRollGame({super.key}) : super(config: const ClassicGameConfig(
    title: 'Dice Roll',
    instruction: 'اختر أعلى نتيجة للنرد',
    options: ["1","3","5","6"],
    correctIndex: 3,
  ));
}
