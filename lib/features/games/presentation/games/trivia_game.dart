import '../classic_game_engine.dart';

class TriviaGame extends ClassicGameEngine {
  TriviaGame({super.key}) : super(config: const ClassicGameConfig(
    title: 'Trivia',
    instruction: 'أجب عن السؤال العام',
    options: ["المحيط الهادئ","الأطلسي","الهندي","المتجمد"],
    correctIndex: 0,
  ));
}
