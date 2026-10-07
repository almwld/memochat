import 'dart:math' as math;
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/game_service.dart';
import '../../models/game.dart';
import 'arcade_content.dart';

class MemoArcadeScreen extends StatefulWidget {
  const MemoArcadeScreen({super.key, required this.type, this.chatId = '', this.gameId});
  final GameType type;
  final String chatId;
  final String? gameId;
  @override State<MemoArcadeScreen> createState() => _MemoArcadeScreenState();
}

class _MemoArcadeScreenState extends State<MemoArcadeScreen> with WidgetsBindingObserver {
  late final MemoArcadeGame game;
  @override void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    game = MemoArcadeGame(type: widget.type, chatId: widget.chatId, gameId: widget.gameId, onScore: (_) { if (mounted) setState(() {}); });
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      game.resumeEngine();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      game.pauseEngine();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    game.pauseEngine();
    super.dispose();
  }
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
        game.tap(Vector2(p.dx, p.dy));
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

  ArcadeContent get content => ArcadeContentBank.forType(type);
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
    if (const {ArcadeMode.quiz, ArcadeMode.math, ArcadeMode.word, ArcadeMode.code, ArcadeMode.lights, ArcadeMode.pairs, ArcadeMode.choice, ArcadeMode.race, ArcadeMode.oddOneOut}.contains(content.mode)) { _renderSpecial(canvas); return; }
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
      if (type == GameType.shapeMatch || type == GameType.patternTap) {
        final path=Path();
        for(var i=0;i<10;i++){final a=-math.pi/2+i*math.pi/5;final rr=i.isEven?r:r*.45;final q=Offset(c.dx+math.cos(a)*rr,c.dy+math.sin(a)*rr);if(i==0)path.moveTo(q.dx,q.dy);else path.lineTo(q.dx,q.dy);}
        canvas.drawPath(path..close(),paint);
      } else if (type == GameType.colorRush || type == GameType.colorMatch) {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCircle(center:c,radius:r),const Radius.circular(10)),paint);
      } else if (type == GameType.mazeRunner || type == GameType.treasureHunt || type == GameType.galaxyCatch) {
        final path=Path()..moveTo(c.dx,c.dy-r)..lineTo(c.dx+r,c.dy)..lineTo(c.dx,c.dy+r)..lineTo(c.dx-r,c.dy)..close();canvas.drawPath(path,paint);
      } else { canvas.drawCircle(c,r,paint); }
      paint.color=Colors.white.withOpacity(.2); canvas.drawCircle(Offset(c.dx-r*.28,c.dy-r*.28),r*.18,paint);
    }
    for(final p in particles){paint.color=palette[p.kind%palette.length].withOpacity(math.max(0,1-p.age/.7));canvas.drawCircle(Offset(p.position.x,p.position.y),p.radius*(1+p.age*2),paint);}
    final hud=TextPainter(text:TextSpan(text:content.title+'  •  '+score.toString()+' نقطة',style:const TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w900)),textDirection:TextDirection.rtl)..layout();
    hud.paint(canvas,Offset(size.x/2-hud.width/2,20));
    final help=TextPainter(text:TextSpan(text:_instruction,style:const TextStyle(color:Color(0xB8FFFFFF),fontSize:12,fontWeight:FontWeight.w700)),textDirection:TextDirection.rtl)..layout();
    help.paint(canvas,Offset(size.x/2-help.width/2,49));
  }

  String get _instruction {
    return content.instruction;
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
      case GameType.quizBattle:
      case GameType.trivia:
      case GameType.trueFalse:
      case GameType.flagQuiz:
      case GameType.animalQuiz:
      case GameType.geographyQuiz:
      case GameType.scienceQuiz:
      case GameType.historyQuiz:
      case GameType.languageQuiz:
      case GameType.riddleRush:
        _tapChoice(point); return;
      case GameType.speedMath:
      case GameType.numberGuess:
      case GameType.mathDuel:
        _tapMath(point); return;
      case GameType.wordScramble:
      case GameType.wordChain:
      case GameType.anagramBattle:
      case GameType.wordGuess:
        _tapWord(point); return;
      case GameType.codeBreaker: _tapCode(point); return;
      case GameType.lightSwitch: _tapLights(point); return;
      case GameType.connectPairs:
      case GameType.picturePuzzle:
      case GameType.sudokuDuel:
      case GameType.fourInRow:
      case GameType.dotsAndBoxes:
        _tapPairs(point); return;
      case GameType.fastChoice:
      case GameType.higherLower:
      case GameType.emojiReaction:
      case GameType.drawGuess:
      case GameType.truthDare:
      case GameType.guessSong:
      case GameType.movieQuiz:
      case GameType.wouldYouRather:
        _tapChoice(point); return;
      case GameType.oddOneOut: _tapOddOneOut(point); return;
      case GameType.rocketRace: _tapRace(point); return;
      default: _tapTarget(point);
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

  int _specialRound = 0;
  int _specialSecret = 0;
  final List<bool> _lights = List<bool>.filled(9, true);
  int _raceProgress = 0;

  void _renderSpecial(Canvas canvas) {
    final paint = Paint();
    paint.color = const Color(0xFF0B2225);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
    final h = TextPainter(text: TextSpan(text: content.title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)), textDirection: TextDirection.rtl)..layout(maxWidth: size.x - 30);
    h.paint(canvas, Offset(size.x / 2 - h.width / 2, 18));
    final i = TextPainter(text: TextSpan(text: content.instruction, style: const TextStyle(color: Color(0xB8FFFFFF), fontSize: 13, fontWeight: FontWeight.w700)), textDirection: TextDirection.rtl)..layout(maxWidth: size.x - 30);
    i.paint(canvas, Offset(size.x / 2 - i.width / 2, 52));
    switch (content.mode) {
      case ArcadeMode.quiz: _renderOptions(canvas, content.prompts.isEmpty ? 'اختر الإجابة الصحيحة' : content.prompts[_specialRound % content.prompts.length], content.options); break;
      case ArcadeMode.choice: _renderOptions(canvas, 'اختر خيارك', content.options); break;
      case ArcadeMode.math:
        _specialSecret = _specialSecret == 0 ? 10 + random.nextInt(50) : _specialSecret;
        final q = type == GameType.numberGuess ? 'الرقم السري قريب من $_specialSecret' : '$_specialSecret + ${5 + (_specialRound % 9)} = ؟';
        _renderOptions(canvas, q, ['${_specialSecret + 5}', '${_specialSecret + 7}', '${_specialSecret + 3}', '${_specialSecret + 9}']); break;
      case ArcadeMode.word:
        final source = content.prompts.isEmpty ? 'كتاب' : content.prompts[_specialRound % content.prompts.length];
        final chars = source.runes.toList()..shuffle(random);
        _renderOptions(canvas, 'رتب: ${String.fromCharCodes(chars)}', [source, 'هاتف', 'شجرة', 'مدينة']); break;
      case ArcadeMode.code: _renderOptions(canvas, 'اضغط لمحاولة كسر الشفرة', ['0','1','2','3']); break;
      case ArcadeMode.lights:
        for (var n = 0; n < 9; n++) { final x = 12 + (n % 3) * ((size.x - 24) / 3); final y = 100 + (n ~/ 3) * 68; paint.color = _lights[n] ? const Color(0xFFFFD166) : const Color(0xFF17383B); canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, (size.x - 36) / 3, 52), const Radius.circular(12)), paint); } break;
      case ArcadeMode.pairs:
        for (var n = 0; n < 16; n++) { final w = (size.x - 36) / 4; final x = 8 + (n % 4) * w; final y = 105 + (n ~/ 4) * 60; paint.color = palette[n % palette.length]; canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w - 5, 52), const Radius.circular(10)), paint); } break;
      case ArcadeMode.race:
        paint.color = const Color(0xFF39D5C5); canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(18, size.y * .52, size.x - 36, 18), const Radius.circular(9)), paint); paint.color = Colors.white; final x = 24 + (_raceProgress / 100) * (size.x - 48); canvas.drawCircle(Offset(x, size.y * .52 + 9), 14, paint); break;
      case ArcadeMode.oddOneOut:
        for (var n = 0; n < 12; n++) { final w = (size.x - 36) / 4; final x = 8 + (n % 4) * w; final y = 110 + (n ~/ 4) * 65; paint.color = palette[n % palette.length]; canvas.drawCircle(Offset(x + w / 2, y + 22), n == 7 ? 21 : 16, paint); } break;
      default: break;
    }
    final s = TextPainter(text: TextSpan(text: '$score نقطة', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)), textDirection: TextDirection.rtl)..layout();
    s.paint(canvas, Offset(size.x / 2 - s.width / 2, size.y - 38));
  }

  void _renderOptions(Canvas canvas, String prompt, List<String> options) {
    final p = TextPainter(text: TextSpan(text: prompt, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)), textDirection: TextDirection.rtl)..layout(maxWidth: size.x - 28);
    p.paint(canvas, Offset(size.x / 2 - p.width / 2, 92));
    final paint = Paint();
    final visible = options.take(4).toList();
    for (var n = 0; n < visible.length; n++) { final y = 150 + n * 62.0; paint.color = palette[n % palette.length]; canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(18, y, size.x - 36, 48), const Radius.circular(14)), paint); final t = TextPainter(text: TextSpan(text: visible[n], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)), textDirection: TextDirection.rtl)..layout(maxWidth: size.x - 50); t.paint(canvas, Offset(size.x / 2 - t.width / 2, y + 13)); }
  }

  void _tapChoice(Vector2 point) { final n = ((point.y - 150) / 62).floor(); if (n < 0 || n > 3) return; score += n == 0 ? 2 : 1; _specialRound++; onScore(score); _syncScore(); }
  void _tapMath(Vector2 point) { final n = ((point.y - 150) / 62).floor(); if (n < 0 || n > 3) return; score += n == 0 ? 3 : 0; _specialRound++; _specialSecret = 10 + random.nextInt(50); onScore(score); _syncScore(); }
  void _tapWord(Vector2 point) { final n = ((point.y - 150) / 62).floor(); if (n < 0 || n > 3) return; score += n == 0 ? 3 : 1; _specialRound++; onScore(score); _syncScore(); }
  void _tapCode(Vector2 point) { if (point.y < 140) return; score += 2; _specialRound++; onScore(score); _syncScore(); }
  void _tapLights(Vector2 point) { if (point.y < 100) return; final col = ((point.x - 8) / ((size.x - 24) / 3)).floor(); final row = ((point.y - 100) / 68).floor(); if (row < 0 || row > 2 || col < 0 || col > 2) return; final n = row * 3 + col; for (final j in [n, n - 1, n + 1, n - 3, n + 3]) { if (j >= 0 && j < 9 && (j ~/ 3 == row || j % 3 == col)) _lights[j] = !_lights[j]; } if (_lights.every((v) => !v)) { score += 5; for (var k = 0; k < 9; k++) _lights[k] = true; onScore(score); _syncScore(); } }
  void _tapPairs(Vector2 point) { if (point.y < 100) return; score += 1; onScore(score); _syncScore(); }
  void _tapOddOneOut(Vector2 point) { if (point.y < 100) return; final col = (point.x / ((size.x - 12) / 4)).floor(); final row = ((point.y - 110) / 65).floor(); final n = row * 4 + col; if (n < 0 || n >= 12) return; score += n == 7 ? 4 : 0; onScore(score); _syncScore(); }
  void _tapRace(Vector2 point) { if (point.y < size.y * .42) return; _raceProgress = math.min(100, _raceProgress + 8); score++; if (_raceProgress >= 100) { score += 10; _raceProgress = 0; } onScore(score); _syncScore(); }
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
class Target { Target({required this.position,required this.radius,required this.velocity,required this.kind,required this.phase}); Vector2 position,velocity; final double radius,phase; final int kind; double age=0; }
class Particle { Particle({required this.position,required this.velocity,required this.radius,required this.kind}); Vector2 position,velocity; final double radius; final int kind; double age=0; }
