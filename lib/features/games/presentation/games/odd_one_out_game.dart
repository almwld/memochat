import '../extended_game_engine.dart';

class OddOneOutGame extends ExtendedGameEngine {
  OddOneOutGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Odd One Out',
    instruction: 'حدد العنصر المختلف',
    options: ["●","●","◆","●"],
    correctIndex: 2,
  ));
}
