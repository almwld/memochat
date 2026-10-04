import 'classic_game_engine.dart';

class SpeedMathGame extends ClassicGameEngine {
  SpeedMathGame({super.key}) : super(config: const ClassicGameConfig(
    title: 'Speed Math',
    instruction: 'اختر نتيجة العملية الحسابية',
    options: ["10","12","14","16"],
    correctIndex: 1,
  ));
}
