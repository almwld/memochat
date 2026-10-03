import '../extended_game_engine.dart';

class EmojiMemoryGame extends ExtendedGameEngine {
  EmojiMemoryGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Emoji Memory',
    instruction: 'طابق الرمز مع شريكه',
    options: ["🍎","🚀","🎵","⚽"],
    correctIndex: 0,
  ));
}
