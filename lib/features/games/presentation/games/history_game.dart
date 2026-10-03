import '../extended_game_engine.dart';

class HistoryGame extends ExtendedGameEngine {
  HistoryGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'History',
    instruction: 'حدد الحقبة الصحيحة',
    options: ["القديمة","الوسطى","الحديثة","المعاصرة"],
    correctIndex: 0,
  ));
}
