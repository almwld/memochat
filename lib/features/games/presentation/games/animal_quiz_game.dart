import 'extended_game_engine.dart';

class AnimalQuizGame extends ExtendedGameEngine {
  AnimalQuizGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Animal Quiz',
    instruction: 'حدد الحيوان الصحيح',
    options: ["فهد","حوت","نسر","فيل"],
    correctIndex: 0,
  ));
}
