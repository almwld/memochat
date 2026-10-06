import 'package:flutter_test/flutter_test.dart';
import 'package:memochat/features/games/data/games_catalog.dart';
import 'package:memochat/features/games/services/game_performance_budget.dart';

void main() {
  test('the complete 55-game catalog stays unique and cheap to traverse', () {
    expect(GamesCatalog.all.length, GamePerformanceBudget.catalogSize);
    expect(GamesCatalog.all.map((game) => game.type).toSet().length, GamePerformanceBudget.catalogSize);

    final stopwatch = Stopwatch()..start();
    var checksum = 0;
    for (var pass = 0; pass < 2000; pass++) {
      for (final game in GamesCatalog.all) {
        checksum += game.type.index + game.title.length + game.subtitle.length;
      }
    }
    stopwatch.stop();

    expect(checksum, greaterThan(0));
    // This is a deterministic regression guard for catalog work on the UI
    // isolate; it does not pretend to replace a device frame profile.
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
  });

  test('animation and particle budgets remain safe for 60fps surfaces', () {
    expect(GamePerformanceBudget.isAnimationWithinBudget(const Duration(milliseconds: 180)), isTrue);
    expect(GamePerformanceBudget.isAnimationWithinBudget(const Duration(milliseconds: 240)), isTrue);
    expect(GamePerformanceBudget.isAnimationWithinBudget(const Duration(milliseconds: 301)), isFalse);
    expect(GamePerformanceBudget.targetFrameMilliseconds, 16);
    expect(GamePerformanceBudget.maxParticlesPerBurst, lessThanOrEqualTo(24));
  });
}
