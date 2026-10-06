import 'dart:math' as math;
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/game_service.dart';
import '../models/game.dart';

class MemoArcadeScreen extends StatefulWidget {
  const MemoArcadeScreen({super.key, required this.type, this.chatId = '', this.gameId});
  final GameType type;
  final String chatId;
  final String? gameId;
  @override State<MemoArcadeScreen> createState() => _MemoArcadeScreenState();
}

class _MemoArcadeScreenState extends State<MemoArcadeScreen> {
  late final MemoArcadeGame game;
  @override void initState() {
    super.initState();
    game = MemoArcadeGame(type: widget.type, chatId: widget.chatId, gameId: widget.gameId, onScore: (_) { if (mounted) setState(() {}); });
  }
  @override void dispose() { game.pauseEngine(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(game.title), centerTitle: true,
      actions: [Padding(padding: const EdgeInsetsDirectional.only(end: 14),
        child: Center(child: Text(game.score.toString(),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))))]),
    body: Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        final box = context.findRenderObject() as RenderBox;
        final p = box.globalToLocal(e.position);
        game.tap(Vector2(p.dx, p.dy - kToolbarHeight));
      },
      child: GameWidget(game: game),
    ),
  );
}

class MemoArcadeGame extends FlameGame {
  MemoArcadeGame({required this.type, required this.onScore, this.chatId = '', this.gameId})
      : title = _titles[type] ?? 'Memo Arcade';
  final GameType type;
  final ValueChanged<int> onScore;
  final String chatId;
  final String? gameId;
  final String title;
  final math.Random random = math.Random();
  final List<Target> targets = <Target>[];
  final List<Particle> particles = <Particle>[];
  int score = 0;
  double elapsed = 0, spawnClock = 0, comboClock = 0;

  int get profile => type.index % 8;
  Color get background => const Color(0xFF071719);
  List<Color> get palette {
    const p = <List<Color>>[
      [Color(0xFF18B6A4), Color(0xFF43C7E8), Color(0xFF7C83FF)],
      [Color(0xFFFFC857), Color(0xFFFF7A59), Color(0xFFFF4D8D)],
      [Color(0xFF9B7CFF), Color(0xFF54D6FF), Color(0xFF6EF3B1)],
      [Color(0xFF28D7C0), Color(0xFFB3F55A), Color(0xFFFFD166)],
    ];
    return p[type.index % p.length];
  }

  @override Color backgroundColor() => background;

  @override void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (targets.isEmpty && size.x > 0) {
      for (var i = 0; i < 7; i++) spawnTarget();
    }
  }

  void spawnTarget() {
    if (targets.length >= 11 || size.x < 30 || size.y < 120) return;
    final r = 18 + random.nextDouble() * 28;
    targets.add(Target(
      position: Vector2(r + random.nextDouble() * math.max(1, size.x - r * 2),
        90 + r + random.nextDouble() * math.max(1, size.y - 105 - r * 2)),
      radius: r,
      velocity: Vector2((random.nextDouble()-.5)*100, (random.nextDouble()-.5)*100),
      kind: random.nextInt(3), phase: random.nextDouble()*math.pi*2));
  }

  @override void update(double dt) {
    super.update(dt); elapsed += dt; spawnClock += dt; comboClock += dt;
    if (spawnClock > .7) { spawnClock = 0; spawnTarget(); }
    for (final t in targets) {
      t.age += dt; t.position += t.velocity * dt;
      final r = t.radius;
      if (t.position.x < r || t.position.x > size.x-r) {
        t.velocity.x *= -1; t.position.x = t.position.x.clamp(r,size.x-r).toDouble();
      }
      if (t.position.y < 75+r || t.position.y > size.y-r) {
        t.velocity.y *= -1; t.position.y = t.position.y.clamp(75+r,size.y-r).toDouble();
      }
    }
    targets.removeWhere((t) => t.age > 7);
    for (final p in particles) { p.age += dt; p.position += p.velocity*dt; }
    particles.removeWhere((p) => p.age > .7);
  }

  @override void render(Canvas canvas) {
    super.render(canvas);
    final paint = Paint();
    paint.color = const Color(0xFF0B2225);
    canvas.drawRect(Rect.fromLTWH(0,0,size.x,size.y),paint);
    paint..style=PaintingStyle.stroke..strokeWidth=1..color=const Color(0x2039D5C5);
    for (double x=0;x<size.x;x+=32) canvas.drawLine(Offset(x,78),Offset(x,size.y),paint);
    for (double y=80;y<size.y;y+=32) canvas.drawLine(Offset(0,y),Offset(size.x,y),paint);
    paint.style=PaintingStyle.fill;
    for (final t in targets) {
      final r=t.radius*(1+math.sin(t.age*5+t.phase)*.08);
      paint.color=palette[t.kind%palette.length];
      final c=Offset(t.position.x,t.position.y);
      if (profile==1 || profile==5) {
        final path=Path();
        for(var i=0;i<10;i++){final a=-math.pi/2+i*math.pi/5;final rr=i.isEven?r:r*.45;final q=Offset(c.dx+math.cos(a)*rr,c.dy+math.sin(a)*rr);if(i==0)path.moveTo(q.dx,q.dy);else path.lineTo(q.dx,q.dy);}
        canvas.drawPath(path..close(),paint);
      } else if (profile==2 || profile==6) {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCircle(center:c,radius:r),const Radius.circular(10)),paint);
      } else if (profile==3 || profile==7) {
        final path=Path()..moveTo(c.dx,c.dy-r)..lineTo(c.dx+r,c.dy)..lineTo(c.dx,c.dy+r)..lineTo(c.dx-r,c.dy)..close();canvas.drawPath(path,paint);
      } else { canvas.drawCircle(c,r,paint); }
      paint.color=Colors.white.withOpacity(.2); canvas.drawCircle(Offset(c.dx-r*.28,c.dy-r*.28),r*.18,paint);
    }
    for(final p in particles){paint.color=palette[p.kind%palette.length].withOpacity(math.max(0,1-p.age/.7));canvas.drawCircle(Offset(p.position.x,p.position.y),p.radius*(1+p.age*2),paint);}
    final hud=TextPainter(text:TextSpan(text:title+'  •  '+score.toString()+' نقطة',style:const TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w900)),textDirection:TextDirection.rtl)..layout();
    hud.paint(canvas,Offset(size.x/2-hud.width/2,20));
    final help=TextPainter(text:TextSpan(text:_instruction,style:const TextStyle(color:Color(0xB8FFFFFF),fontSize:12,fontWeight:FontWeight.w700)),textDirection:TextDirection.rtl)..layout();
    help.paint(canvas,Offset(size.x/2-help.width/2,49));
  }

  String get _instruction {
    const a=['اضغط الأهداف المتحركة','التقط النجوم قبل اختفائها','اضرب الأشكال المتحركة','اجمع الأهداف المتوهجة','طابق الحركة مع اللحظة المناسبة','احصل على أكبر سلسلة','اضغط بسرعة وتجنب الأخطاء','اصنع أعلى نتيجة'];
    return a[profile];
  }

  void tap(Vector2 point) {
    switch (type) {
      case GameType.memoryMatch:
      case GameType.cardFlip:
      case GameType.emojiMemory:
        _tapMemory(point);
        return;
      case GameType.colorMatch:
      case GameType.colorRush:
        _tapColor(point);
        return;
      case GameType.patternTap:
      case GameType.sequenceRecall:
      case GameType.rhythmTap:
        _tapSequence(point);
        return;
      case GameType.stackTower:
      case GameType.balanceBeam:
        _tapTiming(point);
        return;
      case GameType.mazeRunner:
      case GameType.treasureHunt:
        _tapExplorer(point);
        return;
      default:
        _tapTarget(point);
    }
  }

  final List<int> _memoryOrder = <int>[];
  final Set<int> _memoryFound = <int>{};
  int _memoryFirst = -1;
  int _sequenceStep = 0;
  int _colorGoal = 0;

  void _tapMemory(Vector2 point) {
    if (_memoryOrder.isEmpty) {
      _memoryOrder.addAll(List<int>.generate(12, (i) => i ~/ 2)..shuffle(random));
    }
    final cell = (((point.y - 100) / math.max(1, size.x / 4)).floor()).clamp(0, 2) * 4 +
        ((point.x / math.max(1, size.x / 4)).floor()).clamp(0, 3);
    if (_memoryFound.contains(cell)) return;
    if (_memoryFirst < 0) {
      _memoryFirst = cell;
      _memoryFound.add(cell);
      return;
    }
    if (_memoryOrder[cell] == _memoryOrder[_memoryFirst]) {
      score += 2;
      _memoryFound.add(cell);
      _memoryFirst = -1;
      onScore(score);
      _syncScore();
    } else {
      _memoryFirst = -1;
      score = math.max(0, score - 1);
      onScore(score);
    }
  }

  void _tapColor(Vector2 point) {
    final expected = _colorGoal % palette.length;
    final index = targets.indexWhere((t) => point.distanceTo(t.position) <= t.radius * 1.2);
    if (index < 0) return;
    final hit = targets[index];
    if (hit.kind == expected) {
      score += 2;
      _colorGoal++;
    } else {
      score = math.max(0, score - 1);
    }
    targets.removeAt(index);
    onScore(score);
    _syncScore();
  }

  void _tapSequence(Vector2 point) {
    if (targets.isEmpty) return;
    final ordered = targets.toList()..sort((a,b) => a.phase.compareTo(b.phase));
    final target = ordered[_sequenceStep % ordered.length];
    if (point.distanceTo(target.position) <= target.radius * 1.25) {
      score += 2;
      _sequenceStep++;
      targets.remove(target);
      onScore(score);
      _syncScore();
    } else {
      score = math.max(0, score - 1);
      onScore(score);
    }
  }

  void _tapTiming(Vector2 point) {
    if (targets.isEmpty) return;
    final target = targets.first;
    final distance = point.distanceTo(target.position);
    if (distance <= target.radius * 1.15) {
      score += 1 + (elapsed.floor() % 3);
      targets.remove(target);
      onScore(score);
      _syncScore();
    } else {
      score = math.max(0, score - 1);
      onScore(score);
    }
  }

  void _tapExplorer(Vector2 point) {
    if (targets.isEmpty) return;
    final target = targets.firstWhere(
      (t) => point.distanceTo(t.position) <= t.radius * 1.4,
      orElse: () => targets.first,
    );
    if (point.distanceTo(target.position) <= target.radius * 1.4) {
      score += target.kind == 2 ? 3 : 1;
      targets.remove(target);
      onScore(score);
      _syncScore();
    }
  }

  void _tapTarget(Vector2 point) {
    Target? hit;
    for (final t in targets.reversed) {
      if (point.distanceTo(t.position) <= t.radius * 1.2) { hit = t; break; }
    }
    if (hit == null) {
      score = math.max(0, score - 1);
      comboClock = 0;
      onScore(score);
      return;
    }
    targets.remove(hit);
    final gain = 1 + (hit.kind == 2 ? 2 : 0) + (comboClock < .55 ? 1 : 0);
    score += gain;
    comboClock = 0;
    onScore(score);
    _syncScore();
  }

  Future<void> _syncScore() async {
    final id = gameId?.trim();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (id == null || id.isEmpty || uid == null || chatId.trim().isEmpty) return;
    try {
      await GameService.instance.updatePlayerState(
        chatId: chatId,
        gameId: id,
        uid: uid,
        state: {'score': score, 'action': 'arcade_hit', 'gameType': type.name},
        score: score,
      );
    } catch (_) {}
  }

  static const _titles=<GameType,String>{
    GameType.xo:'XO Arena',GameType.quizBattle:'Quiz Battle',GameType.emojiReaction:'Emoji Reaction',GameType.diceRoll:'Dice Rush',GameType.drawGuess:'Draw & Guess',GameType.wordChain:'Word Chain',GameType.truthDare:'Truth or Dare',GameType.guessSong:'Song Hunt',GameType.memoryMatch:'Memory Match',GameType.trivia:'Trivia Arena',GameType.quickTap:'Quick Tap',GameType.wouldYouRather:'Choice Clash',GameType.speedMath:'Speed Math',GameType.movieQuiz:'Movie Rush',GameType.sudokuDuel:'Sudoku Duel',GameType.colorRush:'Color Rush',GameType.higherLower:'Higher Lower',GameType.numberGuess:'Number Guess',GameType.wordScramble:'Word Scramble',GameType.emojiMemory:'Emoji Memory',GameType.patternTap:'Pattern Tap',GameType.oddOneOut:'Odd One Out',GameType.fourInRow:'Four in Row',GameType.dotsAndBoxes:'Dots & Boxes',GameType.reactionRace:'Reaction Race',GameType.cardFlip:'Card Flip',GameType.treasureHunt:'Treasure Hunt',GameType.mazeRunner:'Maze Runner',GameType.stackTower:'Stack Tower',GameType.targetHit:'Target Hit',GameType.bubblePop:'Bubble Pop',GameType.colorMatch:'Color Match',GameType.shapeMatch:'Shape Match',GameType.sequenceRecall:'Sequence Recall',GameType.fastChoice:'Fast Choice',GameType.trueFalse:'True / False',GameType.flagQuiz:'Flag Quiz',GameType.animalQuiz:'Animal Quiz',GameType.foodQuiz:'Food Quiz',GameType.geographyQuiz:'Geography',GameType.scienceQuiz:'Science',GameType.historyQuiz:'History',GameType.languageQuiz:'Language',GameType.riddleRush:'Riddle Rush',GameType.anagramBattle:'Anagram Battle',GameType.mathDuel:'Math Duel',GameType.codeBreaker:'Code Breaker',GameType.lightSwitch:'Light Switch',GameType.connectPairs:'Connect Pairs',GameType.wordGuess:'Word Guess',GameType.picturePuzzle:'Picture Puzzle',GameType.balanceBeam:'Balance Beam',GameType.rocketRace:'Rocket Race',GameType.galaxyCatch:'Galaxy Catch',GameType.rhythmTap:'Rhythm Tap',
  };
}
class Target { Target({required this.position,required this.radius,required this.velocity,required this.kind,required this.phase}); final Vector2 position,velocity; final double radius,phase; final int kind; double age=0; }
class Particle { Particle({required this.position,required this.velocity,required this.radius,required this.kind}); final Vector2 position,velocity; final double radius; final int kind; double age=0; }
