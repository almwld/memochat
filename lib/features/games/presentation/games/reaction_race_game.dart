import '../extended_game_engine.dart';

class ReactionRaceGame extends ExtendedGameEngine {
  ReactionRaceGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Reaction Race',
    instruction: 'اختر الاستجابة الأسرع',
    options: ["يمين","يسار","أعلى","أسفل"],
    correctIndex: 0,
  ));
}
