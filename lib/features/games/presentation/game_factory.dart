import 'package:flutter/widgets.dart';
import '../models/game.dart';
import 'runtime/memo_arcade_screen.dart';
import 'games/bubble_pop_game.dart';
import 'games/dice_roll_game.dart';
import 'games/dots_and_boxes_game.dart';
import 'games/four_in_row_game.dart';
import 'games/maze_runner_game.dart';
import 'games/memory_match_game.dart';
import 'games/picture_puzzle_game.dart';
import 'games/rhythm_tap_game.dart';
import 'games/sudoku_duel_game.dart';

class DedicatedGameFactory {
  static Widget? build(
    GameType type, {
    String chatId = '',
    String? gameId,
  }) {
    // The dedicated local games are used only for solo play. Multiplayer
    // sessions stay on MemoArcadeGame so chatId/gameId score synchronization
    // remains authoritative through GameService.
    if (chatId.trim().isEmpty && (gameId == null || gameId.trim().isEmpty)) {
      switch (type) {
        case GameType.bubblePop:
          return const BubblePopGame();
        case GameType.diceRoll:
          return const DiceRollGame();
        case GameType.dotsAndBoxes:
          return const DotsAndBoxesGame();
        case GameType.fourInRow:
          return const FourInRowGame();
        case GameType.mazeRunner:
          return const MazeRunnerGame();
        case GameType.memoryMatch:
          return const MemoryMatchGame();
        case GameType.picturePuzzle:
          return const PicturePuzzleGame();
        case GameType.rhythmTap:
          return const RhythmTapGame();
        case GameType.sudokuDuel:
          return const SudokuDuelGame();
        default:
          break;
      }
    }

    return MemoArcadeScreen(
      type: type,
      chatId: chatId,
      gameId: gameId,
    );
  }
}
