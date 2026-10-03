import 'extended_game_engine.dart';

class HigherLowerGame extends ExtendedGameEngine {
  HigherLowerGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Higher / Lower',
    instruction: 'حدد اتجاه الرقم التالي',
    options: ["أعلى","أقل","متساوي","عشوائي"],
    correctIndex: 0,
  ));
}
