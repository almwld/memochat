import '../extended_game_engine.dart';

class RocketRaceGame extends ExtendedGameEngine {
  RocketRaceGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Rocket Race',
    instruction: 'اختر المسار الأسرع',
    options: ["A","B","C","D"],
    correctIndex: 1,
  ));
}
