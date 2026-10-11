import 'dart:math' as math;

/// Pure rules for the board games used by MemoArcade. Keeping these functions
/// independent of Flame and Firebase makes the move logic easy to test.
class GameBoardRules {
  const GameBoardRules._();

  static const Set<int> mazePathCells = <int>{
    56, 57, 58, 59, 51, 43, 35, 36, 37, 38, 39, 31, 23, 15, 7,
  };

  static bool canMoveMaze(int fromCell, int toCell) {
    if (!mazePathCells.contains(fromCell) || !mazePathCells.contains(toCell)) {
      return false;
    }
    final rowDistance = (fromCell ~/ 8 - toCell ~/ 8).abs();
    final columnDistance = (fromCell % 8 - toCell % 8).abs();
    return rowDistance + columnDistance == 1;
  }

  static int findWinner(
    List<int> board, {
    required int rows,
    required int columns,
    required int runLength,
  }) {
    if (rows <= 0 ||
        columns <= 0 ||
        runLength <= 1 ||
        board.length != rows * columns) {
      return 0;
    }

    const directions = <(int, int)>[(0, 1), (1, 0), (1, 1), (1, -1)];
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final marker = board[row * columns + column];
        if (marker == 0) continue;

        for (final (dr, dc) in directions) {
          final endRow = row + (runLength - 1) * dr;
          final endColumn = column + (runLength - 1) * dc;
          if (endRow < 0 ||
              endRow >= rows ||
              endColumn < 0 ||
              endColumn >= columns) {
            continue;
          }

          var matches = true;
          for (var step = 1; step < runLength; step++) {
            final r = row + step * dr;
            final c = column + step * dc;
            if (board[r * columns + c] != marker) {
              matches = false;
              break;
            }
          }
          if (matches) return marker;
        }
      }
    }
    return 0;
  }

  static bool isValidSudoku4x4(
    List<int> values, {
    bool requireComplete = true,
  }) {
    if (values.length != 16 ||
        values.any((value) => value < 0 || value > 4)) {
      return false;
    }
    if (requireComplete && values.any((value) => value == 0)) return false;

    bool hasDuplicate(Iterable<int> values) {
      final seen = <int>{};
      for (final value in values) {
        if (value == 0) continue;
        if (!seen.add(value)) return true;
      }
      return false;
    }

    for (var row = 0; row < 4; row++) {
      if (hasDuplicate(values.skip(row * 4).take(4))) return false;
    }
    for (var column = 0; column < 4; column++) {
      if (hasDuplicate(
        List<int>.generate(4, (row) => values[row * 4 + column]),
      )) {
        return false;
      }
    }
    for (var blockRow = 0; blockRow < 2; blockRow++) {
      for (var blockColumn = 0; blockColumn < 2; blockColumn++) {
        final block = <int>[];
        for (var row = 0; row < 2; row++) {
          for (var column = 0; column < 2; column++) {
            block.add(
              values[(blockRow * 2 + row) * 4 + blockColumn * 2 + column],
            );
          }
        }
        if (hasDuplicate(block)) return false;
      }
    }
    return true;
  }

  static bool isSolvedPicture(List<int> tiles) {
    if (tiles.length != 16) return false;
    for (var index = 0; index < tiles.length; index++) {
      final expected = index == 15 ? 0 : index + 1;
      if (tiles[index] != expected) return false;
    }
    return true;
  }

  /// Builds a solvable 4x4 sliding puzzle by applying legal blank moves to
  /// the solved board, instead of shuffling into an unsolvable permutation.
  static List<int> scramblePicture({required int seed, int moves = 32}) {
    final tiles = List<int>.generate(16, (index) => index == 15 ? 0 : index + 1);
    final random = math.Random(seed);
    var blank = 15;
    var previousBlank = -1;

    for (var move = 0; move < moves; move++) {
      final row = blank ~/ 4;
      final column = blank % 4;
      final neighbors = <int>[
        if (row > 0) blank - 4,
        if (row < 3) blank + 4,
        if (column > 0) blank - 1,
        if (column < 3) blank + 1,
      ]..remove(previousBlank);
      final next = neighbors[random.nextInt(neighbors.length)];
      tiles[blank] = tiles[next];
      tiles[next] = 0;
      previousBlank = blank;
      blank = next;
    }

    if (isSolvedPicture(tiles)) return scramblePicture(seed: seed + 1, moves: moves + 1);
    return tiles;
  }

  static bool dotsBoxComplete({
    required int row,
    required int column,
    required List<bool> horizontal,
    required List<bool> vertical,
  }) {
    if (row < 0 || row >= 3 || column < 0 || column >= 3 ||
        horizontal.length != 12 || vertical.length != 12) {
      return false;
    }
    final top = horizontal[row * 3 + column];
    final bottom = horizontal[(row + 1) * 3 + column];
    final left = vertical[row * 4 + column];
    final right = vertical[row * 4 + column + 1];
    return top && bottom && left && right;
  }
}
