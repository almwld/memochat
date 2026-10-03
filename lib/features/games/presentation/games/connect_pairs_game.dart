import '../extended_game_engine.dart';

class ConnectPairsGame extends ExtendedGameEngine {
  ConnectPairsGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Connect Pairs',
    instruction: 'صل الزوج المتطابق',
    options: ["A-A","B-C","C-D","D-B"],
    correctIndex: 0,
  ));
}
