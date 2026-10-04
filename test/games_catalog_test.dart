import 'package:flutter_test/flutter_test.dart';
import 'package:memochat/features/games/data/games_catalog.dart';
import 'package:memochat/features/games/models/game.dart';
import 'package:memochat/features/games/presentation/game_factory.dart';

void main() {
  test('games catalog contains all 55 game types exactly once', () {
    expect(GamesCatalog.all.length, 55);
    expect(GamesCatalog.all.map((e) => e.type).toSet().length, 55);
    expect(GamesCatalog.all.map((e) => e.type), containsAll(GameType.values));
  });

  test('every game type has a dedicated renderer or classic fallback', () {
    for (final type in GameType.values) {
      final dedicated = DedicatedGameFactory.build(type);
      // The classic six/several legacy games are intentionally built by
      // GamePlayScreen's switch; all extended games must have a factory widget.
      if (dedicated == null) {
        expect(
          {
            GameType.xo,
            GameType.quizBattle,
            GameType.emojiReaction,
            GameType.diceRoll,
            GameType.drawGuess,
            GameType.wordChain,
            GameType.truthDare,
            GameType.guessSong,
            GameType.memoryMatch,
            GameType.trivia,
            GameType.quickTap,
            GameType.wouldYouRather,
            GameType.speedMath,
            GameType.movieQuiz,
            GameType.sudokuDuel,
          },
          contains(type),
        );
      }
    }
  });
}
