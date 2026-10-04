import 'extended_game_engine.dart';

class GalaxyCatchGame extends ExtendedGameEngine {
  GalaxyCatchGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Galaxy Catch',
    instruction: 'التقط الهدف الصحيح',
    options: ["نجمة","قمر","مذنب","كوكب"],
    correctIndex: 0,
  ));
}
