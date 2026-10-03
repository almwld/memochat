import '../extended_game_engine.dart';

class BubblePopGame extends ExtendedGameEngine {
  BubblePopGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Bubble Pop',
    instruction: 'اختر الفقاعة المطلوبة',
    options: ["1","2","3","4"],
    correctIndex: 2,
  ));
}
