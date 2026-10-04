import 'classic_game_engine.dart';

class WouldYouRatherGame extends ClassicGameEngine {
  WouldYouRatherGame({super.key}) : super(config: const ClassicGameConfig(
    title: 'Would You Rather',
    instruction: 'اختر تفضيلك',
    options: ["الطيران","السفر","الاختفاء","السرعة"],
    correctIndex: 0,
  ));
}
