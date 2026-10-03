import '../extended_game_engine.dart';

class LightSwitchGame extends ExtendedGameEngine {
  LightSwitchGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Light Switch',
    instruction: 'حدد المفتاح الصحيح',
    options: ["تشغيل","إيقاف","تشغيل","إيقاف"],
    correctIndex: 0,
  ));
}
