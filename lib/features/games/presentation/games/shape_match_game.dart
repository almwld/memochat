import 'extended_game_engine.dart';

class ShapeMatchGame extends ExtendedGameEngine {
  ShapeMatchGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Shape Match',
    instruction: 'طابق الشكل الصحيح',
    options: ["مثلث","دائرة","مربع","معين"],
    correctIndex: 1,
  ));
}
