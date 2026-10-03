import 'extended_game_engine.dart';

class BalanceBeamGame extends ExtendedGameEngine {
  BalanceBeamGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Balance Beam',
    instruction: 'حافظ على التوازن',
    options: ["يسار","يمين","وسط","عشوائي"],
    correctIndex: 2,
  ));
}
