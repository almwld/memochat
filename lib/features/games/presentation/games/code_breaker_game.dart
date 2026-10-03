import 'extended_game_engine.dart';

class CodeBreakerGame extends ExtendedGameEngine {
  CodeBreakerGame({super.key}) : super(config: const ExtendedGameConfig(
    title: 'Code Breaker',
    instruction: 'اختر الشفرة الصحيحة',
    options: ["123","314","721","909"],
    correctIndex: 1,
  ));
}
