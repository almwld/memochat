import 'package:flutter/foundation.dart';

enum GameType {
  xo, quizBattle, emojiReaction, diceRoll, drawGuess, wordChain, truthDare,
  guessSong, memoryMatch, trivia, quickTap, wouldYouRather, speedMath,
  movieQuiz, sudokuDuel,
}

enum GameStatus { waiting, playing, ended }

enum GameTimeLimit { none, fiveMinutes, tenMinutes, fifteenMinutes }

extension GameTimeLimitX on GameTimeLimit {
  Duration? get duration {
    switch (this) {
      case GameTimeLimit.none: return null;
      case GameTimeLimit.fiveMinutes: return const Duration(minutes: 5);
      case GameTimeLimit.tenMinutes: return const Duration(minutes: 10);
      case GameTimeLimit.fifteenMinutes: return const Duration(minutes: 15);
    }
  }

  String get label {
    switch (this) {
      case GameTimeLimit.none: return 'بدون وقت';
      case GameTimeLimit.fiveMinutes: return '5 دقائق';
      case GameTimeLimit.tenMinutes: return '10 دقائق';
      case GameTimeLimit.fifteenMinutes: return '15 دقيقة';
    }
  }
}

@immutable
class GameDefinition {
  final GameType type;
  final String title;
  final String subtitle;
  final String icon;
  final int minPlayers;
  final int maxPlayers;
  final Duration? defaultDuration;

  const GameDefinition({
    required this.type, required this.title, required this.subtitle,
    required this.icon, required this.minPlayers, required this.maxPlayers,
    this.defaultDuration,
  });

  String get playersLabel => minPlayers == maxPlayers
      ? '$minPlayers لاعبين' : '$minPlayers-$maxPlayers لاعبين';
  String get durationLabel => defaultDuration == null
      ? 'بدون وقت' : '${defaultDuration!.inMinutes} دقائق';
}
