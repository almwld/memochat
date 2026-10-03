import '../extended_game_engine.dart';

class GeographyGame extends ExtendedGameEngine {
  GeographyGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Geography',
    instruction: 'حدد القارة المطلوبة',
    options: ["آسيا","أفريقيا","أوروبا","أمريكا"],
    correctIndex: 0,
  ));
}
