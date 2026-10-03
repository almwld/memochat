import 'extended_game_engine.dart';

class FastChoiceGame extends ExtendedGameEngine {
  FastChoiceGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Fast Choice',
    instruction: 'اختر الإجابة قبل انتهاء الجولة',
    options: ["A","B","C","D"],
    correctIndex: 0,
  ));
}
