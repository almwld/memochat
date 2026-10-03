import '../extended_game_engine.dart';

class TreasureHuntGame extends ExtendedGameEngine {
  TreasureHuntGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Treasure Hunt',
    instruction: 'اختر موقع الكنز',
    options: ["الخريطة","الغابة","الكهف","الشاطئ"],
    correctIndex: 2,
  ));
}
