import '../extended_game_engine.dart';

class ColorRushGame extends ExtendedGameEngine {
  ColorRushGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Color Rush',
    instruction: 'اضغط اللون المطلوب بسرعة',
    options: ["🔴 أحمر","🟢 أخضر","🔵 أزرق","🟣 بنفسجي"],
    correctIndex: 0,
  ));
}
