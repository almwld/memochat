import 'classic_game_engine.dart';

class TruthDareGame extends ClassicGameEngine {
  TruthDareGame({super.key}) : super(config: const ClassicGameConfig(
    title: 'Truth or Dare',
    instruction: 'اختر تحدياً للعب',
    options: ["صراحة","تحدي","سؤال","مهمة"],
    correctIndex: 0,
  ));
}
