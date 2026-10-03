import '../extended_game_engine.dart';

class StackTowerGame extends ExtendedGameEngine {
  StackTowerGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Stack Tower',
    instruction: 'اختر القطعة المناسبة للبناء',
    options: ["صغيرة","متوسطة","كبيرة","متوازنة"],
    correctIndex: 3,
  ));
}
