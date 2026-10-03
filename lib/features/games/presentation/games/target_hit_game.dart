import '../extended_game_engine.dart';

class TargetHitGame extends ExtendedGameEngine {
  TargetHitGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Target Hit',
    instruction: 'اختر المركز الأقرب للهدف',
    options: ["10","25","50","100"],
    correctIndex: 2,
  ));
}
