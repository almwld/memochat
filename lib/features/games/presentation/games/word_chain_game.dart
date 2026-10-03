import 'classic_game_engine.dart';

class WordChainGame extends ClassicGameEngine {
  WordChainGame({super.key}) : super(config: const ClassicGameConfig(
    title: 'Word Chain',
    instruction: 'اختر الكلمة التي تكمل السلسلة',
    options: ["كتاب","باب","بحر","ورد"],
    correctIndex: 1,
  ));
}
