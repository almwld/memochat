import '../extended_game_engine.dart';

class CardFlipGame extends ExtendedGameEngine {
  CardFlipGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Card Flip',
    instruction: 'اختر البطاقة المطابقة',
    options: ["A","B","A","C"],
    correctIndex: 0,
  ));
}
