import 'classic_game_engine.dart';

class EmojiReactionGame extends ClassicGameEngine {
  EmojiReactionGame({super.key}) : super(config: const ClassicGameConfig(
    title: 'Emoji Reaction',
    instruction: 'اختر التفاعل المطلوب بسرعة',
    options: ["❤️","😂","🔥","👏"],
    correctIndex: 0,
  ));
}
