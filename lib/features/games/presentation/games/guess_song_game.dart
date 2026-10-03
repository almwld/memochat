import 'classic_game_engine.dart';

class GuessSongGame extends ClassicGameEngine {
  GuessSongGame({super.key}) : super(config: const ClassicGameConfig(
    title: 'Guess Song',
    instruction: 'اختر نوع الأغنية الصحيح',
    options: ["عربية","روك","كلاسيكية","شعبية"],
    correctIndex: 0,
  ));
}
