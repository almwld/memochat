import 'package:flutter_test/flutter_test.dart';
import 'package:memochat/features/games/data/games_catalog.dart';
import 'package:memochat/features/games/models/game.dart';
import 'package:memochat/features/games/presentation/runtime/arcade_content.dart';

void main() {
  group('MemoChat games catalog', () {
    test('every GameType has exactly one catalog entry', () {
      final catalogTypes = GamesCatalog.all.map((game) => game.type).toList();
      expect(catalogTypes.toSet(), GameType.values.toSet());
      expect(catalogTypes.length, catalogTypes.toSet().length);
    });

    test('every game has non-empty playable content', () {
      final contentTypes = ArcadeContentBank.all.map((item) => item.type).toList();
      expect(contentTypes.toSet(), GameType.values.toSet());
      expect(contentTypes.length, contentTypes.toSet().length);
      for (final item in ArcadeContentBank.all) {
        expect(item.title.trim(), isNotEmpty, reason: item.type.name);
        expect(item.instruction.trim(), isNotEmpty, reason: item.type.name);
      }
    });

    test('all declared quiz answers point to an existing option', () {
      for (final item in ArcadeContentBank.all) {
        for (var i = 0; i < item.correctAnswers.length; i++) {
          final options = item.choicesByPrompt.isNotEmpty &&
                  i < item.choicesByPrompt.length
              ? item.choicesByPrompt[i]
              : item.options;
          expect(
            item.correctAnswers[i],
            inInclusiveRange(0, options.length - 1),
            reason: '${item.type.name}, prompt $i',
          );
        }
      }
    });
  });
}
