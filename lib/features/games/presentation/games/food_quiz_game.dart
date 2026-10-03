import '../extended_game_engine.dart';

class FoodQuizGame extends ExtendedGameEngine {
  FoodQuizGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Food Quiz',
    instruction: 'حدد الطعام الصحيح',
    options: ["بيتزا","سوشي","سلطة","نودلز"],
    correctIndex: 0,
  ));
}
