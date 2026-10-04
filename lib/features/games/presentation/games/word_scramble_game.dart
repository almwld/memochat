import 'extended_game_engine.dart';

class WordScrambleGame extends ExtendedGameEngine {
  WordScrambleGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Word Scramble',
    instruction: 'رتب الحروف لتكوين الكلمة',
    options: ["نجمة","بحر","لعبة","مغامرة"],
    correctIndex: 0,
  ));
}
