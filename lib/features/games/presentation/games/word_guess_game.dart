import '../extended_game_engine.dart';

class WordGuessGame extends ExtendedGameEngine {
  WordGuessGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Word Guess',
    instruction: 'خمن الكلمة',
    options: ["كتاب","بحر","نجمة","شجرة"],
    correctIndex: 0,
  ));
}
