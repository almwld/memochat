import '../extended_game_engine.dart';

class ColorMatchGame extends ExtendedGameEngine {
  ColorMatchGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Color Match',
    instruction: 'طابق اللون مع الاسم',
    options: ["أحمر","أخضر","أزرق","بنفسجي"],
    correctIndex: 0,
  ));
}
