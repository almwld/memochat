import 'extended_game_engine.dart';

class AnagramBattleGame extends ExtendedGameEngine {
  AnagramBattleGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Anagram Battle',
    instruction: 'كوّن الكلمة الصحيحة',
    options: ["نجمة","مغامرة","بحر","صحة"],
    correctIndex: 0,
  ));
}
