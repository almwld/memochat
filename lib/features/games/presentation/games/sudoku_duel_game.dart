import '../classic_game_engine.dart';

class SudokuDuelGame extends ClassicGameEngine {
  SudokuDuelGame({super.key}) : super(config: const ClassicGameConfig(
    title: 'Sudoku Duel',
    instruction: 'اختر الرقم الصحيح للخانة',
    options: ["1","2","3","4"],
    correctIndex: 1,
  ));
}
