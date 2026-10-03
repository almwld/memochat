import '../extended_game_engine.dart';

class SequenceRecallGame extends ExtendedGameEngine {
  SequenceRecallGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Sequence Recall',
    instruction: 'تذكر التسلسل ثم اختره',
    options: ["1-3-2","2-1-3","3-2-1","1-2-3"],
    correctIndex: 3,
  ));
}
