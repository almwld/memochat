import 'extended_game_engine.dart';

class NumberGuessGame extends ExtendedGameEngine {
  NumberGuessGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Number Guess',
    instruction: 'اختر الرقم الأقرب للهدف',
    options: ["3","7","12","18"],
    correctIndex: 1,
  ));
}
