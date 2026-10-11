import 'package:flutter/widgets.dart';
import '../models/game.dart';
import 'runtime/memo_arcade_screen.dart';
import 'board_game_screen.dart';
import 'games/bubble_pop_game.dart';
import 'games/dice_roll_game.dart';
import 'games/dots_and_boxes_game.dart';
import 'games/four_in_row_game.dart';
import 'games/maze_runner_game.dart';
import 'games/memory_match_game.dart';
import 'games/picture_puzzle_game.dart';
import 'games/rhythm_tap_game.dart';
import 'games/sudoku_duel_game.dart';
import 'games/quiz_battle_game.dart';
import 'games/emoji_reaction_game.dart';
import 'games/draw_guess_game.dart';
import 'games/word_chain_game.dart';
import 'games/truth_dare_game.dart';
import 'games/guess_song_game.dart';
import 'games/trivia_game.dart';
import 'games/quick_tap_game.dart';
import 'games/would_you_rather_game.dart';
import 'games/speed_math_game.dart';
import 'games/movie_quiz_game.dart';

class DedicatedGameFactory {
  static Widget build(
    GameType type, {
    String chatId = '',
    String? gameId,
  }) {
    // Board games need their own rules and board state in both solo and
    // multiplayer sessions; do not route them through generic arcade taps.
    const boardGameTypes = <GameType>{
      GameType.xo,
      GameType.fourInRow,
      GameType.dotsAndBoxes,
      GameType.sudokuDuel,
      GameType.picturePuzzle,
      GameType.connectPairs,
    };
    final hasMultiplayerSession =
        chatId.trim().isNotEmpty && (gameId?.trim().isNotEmpty ?? false);
    // Keep existing solo games with their AI/large-board implementations.
    // XO and Connect Pairs need this board implementation even in solo mode.
    if ((hasMultiplayerSession && boardGameTypes.contains(type)) ||
        (!hasMultiplayerSession &&
            const {GameType.xo, GameType.connectPairs}.contains(type))) {
      return BoardGameScreen(type: type, chatId: chatId, gameId: gameId);
    }

    // The dedicated local games are used only for solo play. Multiplayer
    // sessions stay on MemoArcadeGame so chatId/gameId score synchronization
    // remains authoritative through GameService.
    if (chatId.trim().isEmpty && (gameId == null || gameId.trim().isEmpty)) {
      switch (type) {
        case GameType.bubblePop:
          return BubblePopGame();
        case GameType.diceRoll:
          return DiceRollGame();
        case GameType.dotsAndBoxes:
          return DotsAndBoxesGame();
        case GameType.fourInRow:
          return FourInRowGame();
        case GameType.mazeRunner:
          return MazeRunnerGame();
        case GameType.memoryMatch:
          return MemoryMatchGame();
        case GameType.picturePuzzle:
          return PicturePuzzleGame();
        case GameType.rhythmTap:
          return RhythmTapGame();
        case GameType.sudokuDuel:
          return SudokuDuelGame();
        case GameType.quizBattle:
          return QuizBattleGame();
        case GameType.emojiReaction:
          return EmojiReactionGame();
        case GameType.drawGuess:
          return DrawGuessGame();
        case GameType.wordChain:
          return WordChainGame();
        case GameType.truthDare:
          return TruthDareGame();
        case GameType.guessSong:
          return GuessSongGame();
        case GameType.trivia:
          return TriviaGame();
        case GameType.quickTap:
          return QuickTapGame();
        case GameType.wouldYouRather:
          return WouldYouRatherGame();
        case GameType.speedMath:
          return SpeedMathGame();
        case GameType.movieQuiz:
          return MovieQuizGame();
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
