import '../classic_game_engine.dart';

class DrawGuessGame extends ClassicGameEngine {
  DrawGuessGame({super.key}) : super(config: const ClassicGameConfig(
    title: 'Draw & Guess',
    instruction: 'اختر الكلمة التي تطابق الرسم',
    options: ["شمس","بيت","شجرة","سيارة"],
    correctIndex: 1,
  ));
}
