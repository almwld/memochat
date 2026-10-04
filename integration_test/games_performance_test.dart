import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:memochat/features/games/models/game.dart';
import 'package:memochat/features/games/presentation/game_factory.dart';
import 'package:memochat/features/games/presentation/widgets/game_art.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('all 55 games render without jank-heavy animation setup', (tester) async {
    expect(GameType.values.length, 55);

    final timings = <FrameTiming>[];
    binding.addTimingsCallback(timings.addAll);

    for (final type in GameType.values) {
      final widget = DedicatedGameFactory.build(type) ??
          GameArt(type: type, size: 96);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Center(child: widget),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.pump(const Duration(milliseconds: 500));

    final frameCount = timings.length;
    if (frameCount > 0) {
      final buildMs = timings
          .map((t) => t.buildDuration.inMicroseconds / 1000)
          .toList();
      final rasterMs = timings
          .map((t) => t.rasterDuration.inMicroseconds / 1000)
          .toList();
      final worstBuild = buildMs.reduce((a, b) => a > b ? a : b);
      final worstRaster = rasterMs.reduce((a, b) => a > b ? a : b);

      // 16.67ms is the 60Hz frame budget. Keep a small tolerance for
      // device/driver variance while still failing on obvious animation jank.
      expect(worstBuild, lessThan(40));
      expect(worstRaster, lessThan(40));
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
