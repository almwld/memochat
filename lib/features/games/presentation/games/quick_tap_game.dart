import '../classic_game_engine.dart';

class QuickTapGame extends ClassicGameEngine {
  QuickTapGame({super.key}) : super(config: const ClassicGameConfig(
    title: 'Quick Tap',
    instruction: 'اختر أسرع استجابة',
    options: ["1","2","3","4"],
    correctIndex: 3,
  ));
}
