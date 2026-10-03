import 'classic_game_engine.dart';

class QuizBattleGame extends ClassicGameEngine {
  QuizBattleGame({super.key}) : super(config: const ClassicGameConfig(
    title: 'Quiz Battle',
    instruction: 'أجب عن السؤال قبل انتهاء الوقت',
    options: ["المريخ","الأرض","الزهرة","المشتري"],
    correctIndex: 0,
  ));
}
