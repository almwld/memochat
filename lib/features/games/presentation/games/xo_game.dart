import 'classic_game_engine.dart';

class XoGame extends ClassicGameEngine {
  const XoGame({super.key}) : super(config: const ClassicGameConfig(
    title: 'إكس أو',
    instruction: 'اختر الرمز الصحيح بالتناوب',
    options: ['X', 'O', 'X', 'O'],
    correctIndex: 0,
  ));
}
