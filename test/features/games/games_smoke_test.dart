import 'package:flutter_test/flutter_test.dart';
import 'package:memochat/features/games/presentation/games/classic_game_engine.dart';
import 'package:memochat/features/games/presentation/games/extended_game_engine.dart';

void main() {
  test('shared game engines expose playable configuration', () {
    const classic = ClassicGameConfig(
      title: 'Smoke',
      instruction: 'ابدأ',
      options: ['A', 'B', 'C', 'D'],
      correctIndex: 0,
    );
    const extended = ExtendedGameConfig(
      title: 'Smoke Extended',
      instruction: 'ابدأ',
      options: ['1', '2', '3', '4'],
      correctIndex: 0,
    );
    expect(classic.options.length, 4);
    expect(extended.options.length, 4);
    expect(classic.correctIndex, lessThan(classic.options.length));
    expect(extended.correctIndex, lessThan(extended.options.length));
  });
}