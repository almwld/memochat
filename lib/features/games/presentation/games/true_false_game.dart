import '../extended_game_engine.dart';

class TrueFalseGame extends ExtendedGameEngine {
  TrueFalseGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'True / False',
    instruction: 'حدد صحة العبارة',
    options: ["صحيح","خطأ","صحيح","خطأ"],
    correctIndex: 0,
  ));
}
