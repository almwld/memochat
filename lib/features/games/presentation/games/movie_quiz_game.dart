import 'classic_game_engine.dart';

class MovieQuizGame extends ClassicGameEngine {
  MovieQuizGame({super.key}) : super(config: const ClassicGameConfig(
    title: 'Movie Quiz',
    instruction: 'اختر الفيلم الصحيح',
    options: ["Inception","Avatar","Titanic","Matrix"],
    correctIndex: 0,
  ));
}
