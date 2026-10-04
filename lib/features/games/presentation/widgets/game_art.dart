import 'package:flutter/material.dart';
import '../../models/game.dart';

/// Scalable, asset-free game artwork used across the games catalog and rooms.
/// Every game type gets a distinct visual language without relying on emoji glyphs.
class GameArt extends StatelessWidget {
  final GameType type;
  final double size;
  final bool compact;
  const GameArt({super.key, required this.type, this.size = 72, this.compact = false});

  static const _palette = <Color>[
    Color(0xFF0A8F83), Color(0xFF2477FF), Color(0xFF7B61FF),
    Color(0xFFE85D75), Color(0xFFF59E0B), Color(0xFF0EA5A0),
  ];

  int get _seed => type.index;
  Color get _accent => _palette[_seed % _palette.length];

  IconData get _icon {
    switch (type) {
      case GameType.xo: return Icons.grid_3x3_rounded;
      case GameType.quizBattle:
      case GameType.trivia:
      case GameType.trueFalse:
      case GameType.flagQuiz:
      case GameType.animalQuiz:
      case GameType.foodQuiz:
      case GameType.geographyQuiz:
      case GameType.scienceQuiz:
      case GameType.historyQuiz:
      case GameType.languageQuiz:
      case GameType.movieQuiz: return Icons.quiz_rounded;
      case GameType.emojiReaction:
      case GameType.reactionRace:
      case GameType.quickTap:
      case GameType.targetHit:
      case GameType.bubblePop:
      case GameType.rhythmTap: return Icons.flash_on_rounded;
      case GameType.diceRoll: return Icons.casino_rounded;
      case GameType.drawGuess:
      case GameType.picturePuzzle: return Icons.draw_rounded;
      case GameType.wordChain:
      case GameType.wordScramble:
      case GameType.wordGuess:
      case GameType.anagramBattle: return Icons.text_fields_rounded;
      case GameType.truthDare: return Icons.question_mark_rounded;
      case GameType.guessSong: return Icons.music_note_rounded;
      case GameType.memoryMatch:
      case GameType.emojiMemory:
      case GameType.sequenceRecall: return Icons.memory_rounded;
      case GameType.wouldYouRather:
      case GameType.fastChoice: return Icons.compare_arrows_rounded;
      case GameType.speedMath:
      case GameType.mathDuel: return Icons.calculate_rounded;
      case GameType.sudokuDuel: return Icons.grid_on_rounded;
      case GameType.colorRush:
      case GameType.colorMatch: return Icons.palette_rounded;
      case GameType.higherLower: return Icons.swap_vert_rounded;
      case GameType.numberGuess: return Icons.pin_rounded;
      case GameType.patternTap: return Icons.pattern_rounded;
      case GameType.oddOneOut: return Icons.visibility_rounded;
      case GameType.fourInRow:
      case GameType.connectPairs: return Icons.circle_rounded;
      case GameType.dotsAndBoxes: return Icons.grid_view_rounded;
      case GameType.cardFlip: return Icons.style_rounded;
      case GameType.treasureHunt: return Icons.explore_rounded;
      case GameType.mazeRunner: return Icons.route_rounded;
      case GameType.stackTower: return Icons.stacked_bar_chart_rounded;
      case GameType.shapeMatch: return Icons.category_rounded;
      case GameType.codeBreaker: return Icons.lock_open_rounded;
      case GameType.lightSwitch: return Icons.lightbulb_rounded;
      case GameType.balanceBeam: return Icons.balance_rounded;
      case GameType.rocketRace: return Icons.rocket_launch_rounded;
      case GameType.galaxyCatch: return Icons.auto_awesome_rounded;
      case GameType.riddleRush: return Icons.psychology_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = compact ? size * .72 : size;
    return SizedBox(
      width: s, height: s,
      child: CustomPaint(
        painter: _GameArtPainter(accent: _accent, seed: _seed),
        child: Center(child: Icon(_icon, size: s * .42, color: Colors.white)),
      ),
    );
  }
}

class _GameArtPainter extends CustomPainter {
  final Color accent;
  final int seed;
  const _GameArtPainter({required this.accent, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    final bg = Paint()..color = accent.withOpacity(.12);
    final ring = Paint()
      ..color = accent.withOpacity(.26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .055;
    final core = Paint()..color = accent;
    final detail = Paint()
      ..color = Colors.white.withOpacity(.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .035;

    canvas.drawCircle(center, r * .46, bg);
    canvas.drawCircle(center, r * .39, core);
    canvas.drawCircle(center, r * .39, ring);

    final path = Path();
    final variant = seed % 6;
    if (variant == 0) {
      path.moveTo(r * .22, r * .50);
      path.lineTo(r * .78, r * .50);
      path.moveTo(r * .50, r * .22);
      path.lineTo(r * .50, r * .78);
    } else if (variant == 1) {
      path.moveTo(r * .26, r * .70);
      path.lineTo(r * .50, r * .28);
      path.lineTo(r * .74, r * .70);
      path.close();
    } else if (variant == 2) {
      canvas.drawCircle(center, r * .20, detail);
      path.addOval(Rect.fromCircle(center: center, radius: r * .30));
    } else if (variant == 3) {
      path.moveTo(r * .24, r * .34);
      path.lineTo(r * .76, r * .34);
      path.moveTo(r * .24, r * .66);
      path.lineTo(r * .76, r * .66);
    } else if (variant == 4) {
      path.moveTo(r * .30, r * .70);
      path.lineTo(r * .50, r * .28);
      path.lineTo(r * .70, r * .70);
    } else {
      path.moveTo(r * .28, r * .50);
      path.cubicTo(r * .40, r * .20, r * .60, r * .80, r * .72, r * .50);
    }
    canvas.drawPath(path, detail);
  }

  @override
  bool shouldRepaint(covariant _GameArtPainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.seed != seed;
}
