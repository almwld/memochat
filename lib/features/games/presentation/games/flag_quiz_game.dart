import 'extended_game_engine.dart';

class FlagQuizGame extends ExtendedGameEngine {
  FlagQuizGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Flag Quiz',
    instruction: 'حدد الدولة الصحيحة',
    options: ["اليمن","اليابان","البرازيل","فرنسا"],
    correctIndex: 0,
  ));
}
