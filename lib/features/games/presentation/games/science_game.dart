import '../extended_game_engine.dart';

class ScienceGame extends ExtendedGameEngine {
  ScienceGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Science',
    instruction: 'حدد الإجابة العلمية',
    options: ["الماء","الأكسجين","الحديد","الكربون"],
    correctIndex: 1,
  ));
}
