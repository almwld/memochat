import 'extended_game_engine.dart';

class LanguageGame extends ExtendedGameEngine {
  LanguageGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Language',
    instruction: 'حدد نوع الكلمة',
    options: ["اسم","فعل","حرف","صفة"],
    correctIndex: 0,
  ));
}
