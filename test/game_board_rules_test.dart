import 'package:flutter_test/flutter_test.dart';
import 'package:memochat/features/games/presentation/runtime/game_board_rules.dart';

void main() {
  group('GameBoardRules', () {
    test('detects horizontal, vertical, and diagonal wins without false positives', () {
      expect(
        GameBoardRules.findWinner(
          [1, 1, 1, 0, 2, 0, 2, 0, 0],
          rows: 3,
          columns: 3,
          runLength: 3,
        ),
        1,
      );
      expect(
        GameBoardRules.findWinner(
          [1, 2, 0, 1, 0, 2, 0, 2, 1],
          rows: 3,
          columns: 3,
          runLength: 3,
        ),
        0,
      );
      expect(
        GameBoardRules.findWinner(
          [1, 2, 0, 1, 2, 0, 1, 0, 2],
          rows: 3,
          columns: 3,
          runLength: 3,
        ),
        1,
      );
      expect(
        GameBoardRules.findWinner(
          [1, 2, 0, 0, 1, 2, 0, 0, 1],
          rows: 3,
          columns: 3,
          runLength: 3,
        ),
        1,
      );
      expect(
        GameBoardRules.findWinner(
          List<int>.generate(42, (i) => i % 7 == 2 && i ~/ 7 > 2 ? 2 : 0),
          rows: 6,
          columns: 7,
          runLength: 4,
        ),
        0,
      );
    });

    test('maze movement stays on the connected corridor', () {
      expect(GameBoardRules.canMoveMaze(56, 57), isTrue);
      expect(GameBoardRules.canMoveMaze(59, 51), isTrue);
      expect(GameBoardRules.canMoveMaze(56, 59), isFalse);
      expect(GameBoardRules.canMoveMaze(56, 48), isFalse);
      expect(GameBoardRules.canMoveMaze(0, 1), isFalse);
    });

    test('validates complete 4x4 Sudoku rows, columns, and blocks', () {
      const solved = <int>[
        1, 2, 3, 4,
        3, 4, 1, 2,
        2, 1, 4, 3,
        4, 3, 2, 1,
      ];
      expect(GameBoardRules.isValidSudoku4x4(solved), isTrue);
      expect(
        GameBoardRules.isValidSudoku4x4(
          [1, 1, 3, 4, 3, 4, 1, 2, 2, 1, 4, 3, 4, 3, 2, 1],
        ),
        isFalse,
      );
      expect(
        GameBoardRules.isValidSudoku4x4(
          [1, 0, 3, 4, 3, 4, 1, 2, 2, 1, 4, 3, 4, 3, 2, 1],
        ),
        isFalse,
      );
      expect(
        GameBoardRules.isValidSudoku4x4(
          [1, 0, 3, 4, 3, 4, 1, 2, 2, 1, 4, 3, 4, 3, 2, 1],
          requireComplete: false,
        ),
        isTrue,
      );
    });

    test('picture puzzle scramble is solvable and never starts solved', () {
      final first = GameBoardRules.scramblePicture(seed: 2026);
      final second = GameBoardRules.scramblePicture(seed: 2026);
      expect(first, second);
      expect(first.toSet(), Set<int>.from(List<int>.generate(16, (i) => i == 15 ? 0 : i + 1)));
      expect(GameBoardRules.isSolvedPicture(first), isFalse);
      expect(
        GameBoardRules.isSolvedPicture(
          List<int>.generate(16, (i) => i == 15 ? 0 : i + 1),
        ),
        isTrue,
      );
    });

    test('detects a completed dots-and-boxes square', () {
      final horizontal = List<bool>.filled(12, false);
      final vertical = List<bool>.filled(12, false);
      horizontal[0] = true;
      horizontal[3] = true;
      vertical[0] = true;
      vertical[1] = true;
      expect(
        GameBoardRules.dotsBoxComplete(
          row: 0,
          column: 0,
          horizontal: horizontal,
          vertical: vertical,
        ),
        isTrue,
      );
      expect(
        GameBoardRules.dotsBoxComplete(
          row: 1,
          column: 1,
          horizontal: horizontal,
          vertical: vertical,
        ),
        isFalse,
      );
    });
  });
}
