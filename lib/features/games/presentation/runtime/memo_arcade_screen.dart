import 'dart:async';
import 'dart:math' as math;
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/game_service.dart';
import '../../models/game.dart';
import '../../models/game_session.dart';
import 'arcade_content.dart';
import 'game_board_rules.dart';

class MemoArcadeScreen extends StatefulWidget {
  const MemoArcadeScreen({super.key, required this.type, this.chatId = '', this.gameId});
  final GameType type;
  final String chatId;
  final String? gameId;
  @override State<MemoArcadeScreen> createState() => _MemoArcadeScreenState();
}

class _MemoArcadeScreenState extends State<MemoArcadeScreen> with WidgetsBindingObserver {
  final GlobalKey _gameViewportKey = GlobalKey();
  late final MemoArcadeGame game;
  StreamSubscription<GameSession?>? _sessionSubscription;
  int _remoteScore = 0;
  String? _sessionStatus;
  @override void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    game = MemoArcadeGame(type: widget.type, chatId: widget.chatId, gameId: widget.gameId, onScore: (_) { if (mounted) setState(() {}); });
    final chatId = widget.chatId.trim();
    final gameId = widget.gameId?.trim();
    if (chatId.isNotEmpty && gameId != null && gameId.isNotEmpty) {
      _sessionSubscription = GameService.instance.watchGame(chatId, gameId).listen(
        (session) {
          if (!mounted || session == null) return;
          final uid = FirebaseAuth.instance.currentUser?.uid;
          final opponents = session.players.where((id) => id != uid).toList();
          final opponent = opponents.isEmpty ? null : opponents.first;
          final remote = opponent == null ? null : session.scores[opponent];
          final round = session.state['round'];
          setState(() {
            _remoteScore = remote ?? 0;
            _sessionStatus = session.status.name;
          });
          game.applyRemoteState(
            session.state,
            currentTurn: session.currentTurn,
            players: session.players,
            status: session.status.name,
          );
          if (round is num) game.applyRemoteRound(round.toInt());
        },
        onError: (_) {
          if (mounted) setState(() => _sessionStatus = 'offline');
        },
      );
    }
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
    _sessionSubscription?.cancel();
    game.pauseEngine();
    super.dispose();
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(game.title),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 14),
          child: Center(
            child: Text('${game.score} • $_remoteScore',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          ),
        ),
      ],
    ),
    body: Column(
      children: [
        if (_sessionStatus != null && _sessionStatus != 'playing')
          MaterialBanner(
            content: Text(
              _sessionStatus == 'waiting'
                  ? 'بانتظار انضمام اللاعب الآخر'
                  : _sessionStatus == 'ended'
                      ? 'انتهت جلسة اللعبة'
                      : _sessionStatus == 'offline'
                          ? 'انقطع اتصال المزامنة؛ تستمر اللعبة محليًا'
                          : 'حالة اللعبة: $_sessionStatus',
            ),
            actions: [
              TextButton(
                onPressed: () => setState(() {}),
                child: const Text('حسنًا'),
              ),
            ],
          ),
        Expanded(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) {
              final renderObject =
                  _gameViewportKey.currentContext?.findRenderObject();
              if (renderObject is! RenderBox) return;
              final p = renderObject.globalToLocal(e.position);
              final point = Vector2(p.dx, p.dy);
              if (game.supportsDragMovement) {
                game.moveTo(point);
              } else {
                game.tap(point);
              }
            },
            onPointerMove: (e) {
              if (!game.supportsDragMovement) return;
              final renderObject =
                  _gameViewportKey.currentContext?.findRenderObject();
              if (renderObject is! RenderBox) return;
              final p = renderObject.globalToLocal(e.position);
              game.moveTo(Vector2(p.dx, p.dy));
            },
            child: SizedBox.expand(
              key: _gameViewportKey,
              child: GameWidget(game: game),
            ),
          ),
        ),
      ],
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
  int combo = 0;
  Vector2? _playerPosition;
  double elapsed = 0, spawnClock = 0, comboClock = 0;

  static const List<int> _sudokuPuzzle = <int>[
    1, 0, 0, 4,
    0, 4, 1, 0,
    0, 1, 4, 0,
    4, 0, 0, 1,
  ];
  final List<int> _xoBoard = List<int>.filled(9, 0);
  final List<int> _fourBoard = List<int>.filled(42, 0);
  final List<bool> _dotsHorizontal = List<bool>.filled(12, false);
  final List<bool> _dotsVertical = List<bool>.filled(12, false);
  final List<int> _dotsBoxOwners = List<int>.filled(9, 0);
  final List<int> _sudokuValues = List<int>.from(_sudokuPuzzle);
  final List<int> _pictureTiles = <int>[];
  List<String> _sessionPlayers = <String>[];
  String? _currentTurnUid;
  String? _localUid;
  String? _sessionStatus;
  int _xoTurn = 1;
  int _xoWinner = 0;
  int _fourTurn = 1;
  int _fourWinner = 0;
  int _dotsTurn = 1;
  bool _dotsFinished = false;
  int _sudokuTurn = 1;
  bool _sudokuSolved = false;
  bool _pictureSolved = false;

  bool get supportsDragMovement =>
      type == GameType.mazeRunner || type == GameType.galaxyCatch;

  void moveTo(Vector2 point) {
    if (!supportsDragMovement || size.x <= 0 || size.y <= 0) return;
    const margin = 22.0;
    _playerPosition = Vector2(
      point.x.clamp(margin, math.max(margin, size.x - margin)).toDouble(),
      point.y.clamp(84.0, math.max(84.0, size.y - margin)).toDouble(),
    );
  }

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
    if (supportsDragMovement && size.x > 0 && size.y > 0) {
      _playerPosition ??= Vector2(size.x / 2, size.y * .78);
    }
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
    if (supportsDragMovement && _playerPosition != null) {
      final collected = targets.where((target) =>
          target.position.distanceTo(_playerPosition!) < target.radius + 20).toList();
      for (final target in collected) {
        targets.remove(target);
        score += target.kind == 2 ? 3 : 1;
        _spawnBurst(target.position, target.kind);
        onScore(score);
        _syncScore();
      }
    }
    for (final p in particles) { p.age += dt; p.position += p.velocity*dt; }
    particles.removeWhere((p) => p.age > .7);
  }

  @override void render(Canvas canvas) {
    super.render(canvas);
    if (const {ArcadeMode.quiz, ArcadeMode.math, ArcadeMode.word, ArcadeMode.code, ArcadeMode.lights, ArcadeMode.pairs, ArcadeMode.choice, ArcadeMode.race, ArcadeMode.oddOneOut, ArcadeMode.memory}.contains(content.mode)) { _renderSpecial(canvas); return; }
    final paint = Paint();
    paint.color = const Color(0xFF0B2225);
    canvas.drawRect(Rect.fromLTWH(0,0,size.x,size.y),paint);
    paint..style=PaintingStyle.stroke..strokeWidth=1..color=const Color(0x2039D5C5);
    for (double x=0;x<size.x;x+=32) canvas.drawLine(Offset(x,78),Offset(x,size.y),paint);
    for (double y=80;y<size.y;y+=32) canvas.drawLine(Offset(0,y),Offset(size.x,y),paint);
    paint.style=PaintingStyle.fill;
    for (final t in targets) {
      _drawTargetModel(canvas, paint, t);
    }
    _drawPlayer(canvas);
    for(final p in particles){paint.color=palette[p.kind%palette.length].withOpacity(math.max(0,1-p.age/.7));canvas.drawCircle(Offset(p.position.x,p.position.y),p.radius*(1+p.age*2),paint);}
    final comboLabel = combo >= 2 ? '  •  سلسلة $combo!' : '';
    final hud=TextPainter(text:TextSpan(text:content.title+'  •  '+score.toString()+' نقطة'+comboLabel,style:const TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.w900)),textDirection:TextDirection.rtl)..layout();
    hud.paint(canvas,Offset(size.x/2-hud.width/2,20));
    final help=TextPainter(text:TextSpan(text:_instruction,style:const TextStyle(color:Color(0xB8FFFFFF),fontSize:12,fontWeight:FontWeight.w700)),textDirection:TextDirection.rtl)..layout();
    help.paint(canvas,Offset(size.x/2-help.width/2,49));
  }

  void _drawPlayer(Canvas canvas) {
    final player = _playerPosition;
    if (!supportsDragMovement || player == null) return;
    final center = Offset(player.x, player.y);
    final radius = 18 + math.sin(elapsed * 8) * 1.5;
    if (type == GameType.galaxyCatch) {
      final flame = Path()
        ..moveTo(center.dx - radius * .42, center.dy + radius * .42)
        ..lineTo(center.dx, center.dy + radius * 1.45 + random.nextDouble() * 5)
        ..lineTo(center.dx + radius * .42, center.dy + radius * .42)
        ..close();
      final flamePaint = Paint()..color = const Color(0xFFFF9F43).withOpacity(.8);
      canvas.drawPath(flame, flamePaint);
      _drawMesh(canvas, center, radius * .85, elapsed * .9,
          _pyramidVertices, _pyramidFaces, const Color(0xFF56E6FF), tilt: .12);
    } else {
      _drawMesh(canvas, center, radius, elapsed * .65,
          _cubeVertices, _cubeFaces, const Color(0xFF4DE3C1), tilt: .45);
    }
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withOpacity(.65);
    canvas.drawCircle(center, radius * 1.35, ring);
  }

  void _spawnBurst(Vector2 position, int kind) {
    for (var i = 0; i < 9; i++) {
      final angle = math.pi * 2 * i / 9;
      final speed = 38 + random.nextDouble() * 70;
      particles.add(Particle(
        position: Vector2(position.x, position.y),
        velocity: Vector2(math.cos(angle) * speed, math.sin(angle) * speed),
        radius: 2.5 + random.nextDouble() * 3.5,
        kind: kind,
      ));
    }
  }

  // Draw low-poly 3D meshes with perspective projection. These are real
  // procedural vertices/faces, not emoji or a flat diamond standing in for
  // every object. Rotation and face lighting are computed every frame.
  void _drawTargetModel(Canvas canvas, Paint paint, Target target) {
    final pulse = 1 + math.sin(target.age * 4.8 + target.phase) * .045;
    final r = target.radius * pulse;
    final center = Offset(target.position.x, target.position.y);
    final color = palette[target.kind % palette.length];

    paint
      ..style = PaintingStyle.fill
      ..color = Colors.black.withOpacity(.25);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx, center.dy + r * .72),
          width: r * 1.65, height: r * .42),
      paint,
    );

    if (type == GameType.colorRush || type == GameType.colorMatch) {
      final rect = Rect.fromCenter(center: center, width: r * 1.7, height: r * 1.7);
      paint.color = color;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(r * .28)), paint);
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withOpacity(.62);
      canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(2), Radius.circular(r * .25)), paint);
      paint.style = PaintingStyle.fill;
      return;
    }

    if (type == GameType.mazeRunner) {
      final angle = math.sin(target.age * 2.4 + target.phase) * .18;
      final path = Path()
        ..moveTo(center.dx + math.sin(angle) * r, center.dy - r)
        ..lineTo(center.dx + r * .82, center.dy + r * .68)
        ..lineTo(center.dx, center.dy + r * .34)
        ..lineTo(center.dx - r * .82, center.dy + r * .68)
        ..close();
      paint.color = color;
      canvas.drawPath(path, paint);
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withOpacity(.72);
      canvas.drawPath(path, paint);
      paint.style = PaintingStyle.fill;
      return;
    }

    if (type == GameType.galaxyCatch) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(target.age * .55 + target.phase);
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.0, r * .12)
        ..color = const Color(0xB8B7A8FF);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero,
          width: r * 2.35, height: r * .72), paint);
      canvas.restore();
      paint.style = PaintingStyle.fill;
      _drawMesh(canvas, center, r * .78, target.age * .55 + target.phase,
          _sphereVertices, _sphereFaces, color);
      return;
    }

    if (type == GameType.treasureHunt) {
      _drawMesh(canvas, center, r * .9, target.age * .45 + target.phase,
          _gemVertices, _gemFaces, const Color(0xFFFFC857), tilt: .38);
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFFFFF0B0);
      canvas.drawCircle(center, r * .88, paint);
      paint.style = PaintingStyle.fill;
      return;
    }

    if (type == GameType.shapeMatch || type == GameType.patternTap) {
      final meshes = <List<dynamic>>[
        [_cubeVertices, _cubeFaces],
        [_pyramidVertices, _pyramidFaces],
        [_sphereVertices, _sphereFaces],
      ];
      final mesh = meshes[target.kind % meshes.length];
      _drawMesh(canvas, center, r * .82, target.age * .65 + target.phase,
          mesh[0] as List<_Point3>, mesh[1] as List<List<int>>, color);
      return;
    }

    if (type == GameType.stackTower || type == GameType.balanceBeam) {
      _drawMesh(canvas, center, r * .78, target.age * .45 + target.phase,
          _cubeVertices, _cubeFaces, color, tilt: .48);
      return;
    }

    // Most action targets are rendered as shaded, rotating low-poly spheres.
    // Target-hit games get concentric rings to make the hit zone readable.
    _drawMesh(canvas, center, r * .88, target.age * .38 + target.phase,
        _sphereVertices, _sphereFaces, color);
    if (type == GameType.targetHit) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, r * .07)
        ..color = Colors.white.withOpacity(.78);
      canvas.drawCircle(center, r * .56, paint);
      canvas.drawCircle(center, r * .25, paint);
      paint.style = PaintingStyle.fill;
    }
  }

  void _drawMesh(
    Canvas canvas,
    Offset center,
    double scale,
    double angle,
    List<_Point3> vertices,
    List<List<int>> faces,
    Color baseColor, {
    double tilt = .48,
  }) {
    final ca = math.cos(angle);
    final sa = math.sin(angle);
    final ct = math.cos(tilt);
    final st = math.sin(tilt);
    final projected = <Offset>[];
    final depth = <double>[];
    for (final v in vertices) {
      final x = v.x * ca - v.z * sa;
      final z = v.x * sa + v.z * ca;
      final y = v.y * ct - z * st;
      final d = v.y * st + z * ct;
      projected.add(Offset(center.dx + x * scale, center.dy + y * scale));
      depth.add(d);
    }
    final orderedFaces = faces.toList()
      ..sort((a, b) {
        final da = a.fold<double>(0, (sum, i) => sum + depth[i]) / a.length;
        final db = b.fold<double>(0, (sum, i) => sum + depth[i]) / b.length;
        return da.compareTo(db);
      });
    for (var faceIndex = 0; faceIndex < orderedFaces.length; faceIndex++) {
      final face = orderedFaces[faceIndex];
      final path = Path()..moveTo(projected[face.first].dx, projected[face.first].dy);
      for (final index in face.skip(1)) {
        path.lineTo(projected[index].dx, projected[index].dy);
      }
      path.close();
      final light = .07 + (faceIndex % 4) * .075;
      final facePaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Color.lerp(baseColor, Colors.white, light)!
        ..isAntiAlias = true;
      canvas.drawPath(path, facePaint);
      final outline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withOpacity(.55)
        ..isAntiAlias = true;
      canvas.drawPath(path, outline);
    }
    final highlight = Paint()..color = Colors.white.withOpacity(.3);
    canvas.drawCircle(Offset(center.dx - scale * .25, center.dy - scale * .28),
        scale * .11, highlight);
  }

  static const List<_Point3> _cubeVertices = <_Point3>[
    _Point3(-1, -1, -1), _Point3(1, -1, -1),
    _Point3(1, 1, -1), _Point3(-1, 1, -1),
    _Point3(-1, -1, 1), _Point3(1, -1, 1),
    _Point3(1, 1, 1), _Point3(-1, 1, 1),
  ];
  static const List<List<int>> _cubeFaces = <List<int>>[
    [0, 1, 2, 3], [4, 7, 6, 5], [0, 4, 5, 1],
    [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0],
  ];
  static const List<_Point3> _pyramidVertices = <_Point3>[
    _Point3(0, -1.2, 0), _Point3(1, .55, 1),
    _Point3(1, .55, -1), _Point3(-1, .55, -1),
    _Point3(-1, .55, 1),
  ];
  static const List<List<int>> _pyramidFaces = <List<int>>[
    [0, 1, 2], [0, 2, 3], [0, 3, 4], [0, 4, 1], [1, 4, 3, 2],
  ];
  static const List<_Point3> _sphereVertices = <_Point3>[
    _Point3(0, -1, 0),
    _Point3(0, -.45, 1), _Point3(.87, -.45, .5),
    _Point3(.87, -.45, -.5), _Point3(0, -.45, -1),
    _Point3(-.87, -.45, -.5), _Point3(-.87, -.45, .5),
    _Point3(0, .45, 1), _Point3(.87, .45, .5),
    _Point3(.87, .45, -.5), _Point3(0, .45, -1),
    _Point3(-.87, .45, -.5), _Point3(-.87, .45, .5),
    _Point3(0, 1, 0),
  ];
  static const List<List<int>> _sphereFaces = <List<int>>[
    [0, 1, 2], [0, 2, 3], [0, 3, 4], [0, 4, 5], [0, 5, 6], [0, 6, 1],
    [1, 7, 8, 2], [2, 8, 9, 3], [3, 9, 10, 4], [4, 10, 11, 5],
    [5, 11, 12, 6], [6, 12, 7, 1],
    [7, 13, 8], [8, 13, 9], [9, 13, 10], [10, 13, 11],
    [11, 13, 12], [12, 13, 7],
  ];
  static const List<_Point3> _gemVertices = <_Point3>[
    _Point3(0, -1.2, 0), _Point3(1, -.15, 0), _Point3(.5, 0, .87),
    _Point3(-.5, 0, .87), _Point3(-1, -.15, 0),
    _Point3(-.5, 0, -.87), _Point3(.5, 0, -.87), _Point3(0, 1.15, 0),
  ];
  static const List<List<int>> _gemFaces = <List<int>>[
    [0, 1, 2], [0, 2, 3], [0, 3, 4], [0, 4, 5], [0, 5, 6], [0, 6, 1],
    [7, 2, 1], [7, 3, 2], [7, 4, 3], [7, 5, 4], [7, 6, 5], [7, 1, 6],
  ];

  String get _instruction {
    switch (type) {
      case GameType.mazeRunner:
        return 'اسحب للتحرك واجمع الجواهر وتجنب الحواف';
      case GameType.galaxyCatch:
        return 'اسحب المركبة لجمع النجوم وتجنب النيازك';
      default:
        return content.instruction;
    }
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
      case GameType.xo:
        _tapXo(point);
        return;
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
  final Set<int> _memoryVisible = <int>{};
  int _memoryFirst = -1;
  int _sequenceStep = 0;
  int _colorGoal = 0;

  void _tapMemory(Vector2 point) {
    if (_memoryOrder.isEmpty) {
      _memoryOrder.addAll(List<int>.generate(12, (i) => i ~/ 2)..shuffle(random));
    }
    final cellSize = math.max(1, size.x / 4);
    final col = (point.x / cellSize).floor();
    final row = ((point.y - 100) / 62.0).floor();
    if (col < 0 || col >= 4 || row < 0 || row >= 3) return;
    final cell = row * 4 + col;
    if (_memoryFound.contains(cell) || _memoryVisible.contains(cell)) return;
    if (_memoryFirst < 0) {
      _memoryFirst = cell;
      _memoryVisible.add(cell);
      return;
    }
    _memoryVisible.add(cell);
    if (_memoryOrder[cell] == _memoryOrder[_memoryFirst]) {
      score += 2;
      _memoryFound.addAll([_memoryFirst, cell]);
      _memoryFirst = -1;
      onScore(score);
      _syncScore();
    } else {
      _memoryVisible.removeAll([_memoryFirst, cell]);
      _memoryFirst = -1;
      score = math.max(0, score - 1);
      onScore(score);
      _syncScore();
    }
  }

  void _renderMemory(Canvas canvas, Paint paint) {
    if (_memoryOrder.isEmpty) {
      _memoryOrder.addAll(List<int>.generate(12, (i) => i ~/ 2)..shuffle(random));
    }
    final w = (size.x - 36) / 4;
    for (var n = 0; n < 12; n++) {
      final x = 8 + (n % 4) * w;
      final y = 105.0 + (n ~/ 4) * 62.0;
      final visible = _memoryFound.contains(n) || _memoryVisible.contains(n);
      paint.color = visible ? palette[_memoryOrder[n] % palette.length] : const Color(0xFF17383B);
      canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w - 5, 52),
        const Radius.circular(10),
      ), paint);
      if (visible) {
        final t = TextPainter(
          text: TextSpan(
            text: (_memoryOrder[n] + 1).toString(),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        t.paint(canvas, Offset(x + (w - 5 - t.width) / 2, y + 14));
      }
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
      _spawnBurst(target.position, target.kind);
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
      combo = 0;
      comboClock = 0;
      onScore(score);
      return;
    }
    targets.remove(hit);
    combo = comboClock < .65 ? combo + 1 : 1;
    final comboBonus = combo >= 2 ? math.min(4, combo ~/ 2).toInt() : 0;
    final gain = 1 + (hit.kind == 2 ? 2 : 0) + comboBonus;
    score += gain;
    comboClock = 0;
    _spawnBurst(hit.position, hit.kind);
    onScore(score);
    _syncScore();
  }

  int _specialRound = 0;
  int _specialSecret = 0;
  int _codeDigit = -1;
  int _codeAttempts = 0;
  int _mathAddend = 0;
  int _mathCorrect = 0;
  List<int> _mathOptions = const [];
  List<String> _wordOptions = const [];
  int _wordCorrect = 0;
  final List<bool> _lights = List<bool>.filled(9, true);
  final List<int> _pairOrder = <int>[];
  final Set<int> _pairMatched = <int>{};
  int _pairFirst = -1;
  int _raceProgress = 0;

  void applyRemoteState(
    Map<String, dynamic> state, {
    required String? currentTurn,
    required List<String> players,
    required String status,
  }) {
    _sessionPlayers = List<String>.from(players);
    _currentTurnUid = currentTurn;
    _sessionStatus = status;
    _localUid = FirebaseAuth.instance.currentUser?.uid;

    _copyIntList(_xoBoard, state['xoBoard']);
    _copyIntList(_fourBoard, state['fourBoard']);
    _copyBoolList(_dotsHorizontal, state['dotsHorizontal']);
    _copyBoolList(_dotsVertical, state['dotsVertical']);
    _copyIntList(_dotsBoxOwners, state['dotsBoxOwners']);
    _copyIntList(_sudokuValues, state['sudokuValues']);

    final picture = state['pictureTiles'];
    if (picture is List && picture.length == 16) {
      _pictureTiles
        ..clear()
        ..addAll(picture.map((value) => value is num ? value.toInt() : 0));
    }

    _xoWinner = (state['xoWinner'] as num?)?.toInt() ?? _xoWinner;
    _fourWinner = (state['fourWinner'] as num?)?.toInt() ?? _fourWinner;
    _dotsFinished = state['dotsFinished'] == true;
    _sudokuSolved = state['sudokuSolved'] == true;
    _pictureSolved = state['pictureSolved'] == true;
  }

  void _copyIntList(List<int> target, Object? raw) {
    if (raw is! List || raw.length != target.length) return;
    for (var i = 0; i < target.length; i++) {
      target[i] = raw[i] is num ? (raw[i] as num).toInt() : 0;
    }
  }

  void _copyBoolList(List<bool> target, Object? raw) {
    if (raw is! List || raw.length != target.length) return;
    for (var i = 0; i < target.length; i++) {
      target[i] = raw[i] == true;
    }
  }

  bool get _isMultiplayerSession =>
      chatId.trim().isNotEmpty && gameId?.trim().isNotEmpty == true;

  bool get _canPlayTurn {
    if (!_isMultiplayerSession) return true;
    return _sessionStatus == GameStatus.playing.name &&
        _localUid != null &&
        _currentTurnUid == _localUid;
  }

  int _localMarker(int soloTurn) {
    if (!_isMultiplayerSession) return soloTurn;
    if (_localUid == null) return 0;
    final index = _sessionPlayers.indexOf(_localUid!);
    return index < 0 || index > 1 ? 0 : index + 1;
  }

  String? _nextTurnUid() {
    if (!_isMultiplayerSession || _sessionPlayers.length < 2 || _localUid == null) {
      return null;
    }
    for (final player in _sessionPlayers) {
      if (player != _localUid) return player;
    }
    return _localUid;
  }

  Future<void> _syncBoardState(
    Map<String, dynamic> boardState, {
    String? currentTurn,
  }) async {
    final id = gameId?.trim();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (id == null || id.isEmpty || uid == null || chatId.trim().isEmpty) return;
    if (currentTurn != null) _currentTurnUid = currentTurn;
    try {
      await GameService.instance.updatePlayerState(
        chatId: chatId,
        gameId: id,
        uid: uid,
        state: <String, dynamic>{
          ...boardState,
          'gameType': type.name,
          'round': _specialRound,
        },
        score: score,
        currentTurn: currentTurn,
      );
    } catch (_) {
      // The board remains playable locally if the realtime session is offline.
    }
  }

  void applyRemoteRound(int round) {
    if (round < 0 || round == _specialRound) return;
    _specialRound = round;
    _mathOptions = const [];
    _wordOptions = const [];
    _specialSecret = 0;
    _mathAddend = 0;
    _codeDigit = -1;
  }

  void _renderSpecial(Canvas canvas) {
    final paint = Paint();
    paint.color = const Color(0xFF0B2225);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
    final h = TextPainter(text: TextSpan(text: content.title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)), textDirection: TextDirection.rtl)..layout(maxWidth: size.x - 30);
    h.paint(canvas, Offset(size.x / 2 - h.width / 2, 18));
    final i = TextPainter(text: TextSpan(text: content.instruction, style: const TextStyle(color: Color(0xB8FFFFFF), fontSize: 13, fontWeight: FontWeight.w700)), textDirection: TextDirection.rtl)..layout(maxWidth: size.x - 30);
    i.paint(canvas, Offset(size.x / 2 - i.width / 2, 52));
    switch (content.mode) {
      case ArcadeMode.quiz: { final q = content.prompts.isEmpty ? 'اختر الإجابة الصحيحة' : content.prompts[_specialRound % content.prompts.length]; final n = content.prompts.isEmpty ? 0 : _specialRound % content.prompts.length; final opts = content.choicesByPrompt.isNotEmpty && n < content.choicesByPrompt.length ? content.choicesByPrompt[n] : content.options; _renderOptions(canvas, q, opts); break; }
      case ArcadeMode.choice:
        if (type == GameType.xo) {
          _renderXo(canvas, paint);
          break;
        }
        final n = content.prompts.isEmpty ? 0 : _specialRound % content.prompts.length;
        final prompt = content.prompts.isEmpty ? 'اختر أحد الخيارات' : content.prompts[n];
        final opts = content.choicesByPrompt.isNotEmpty && n < content.choicesByPrompt.length
            ? content.choicesByPrompt[n]
            : content.options;
        _renderOptions(canvas, prompt, opts);
        break;
      case ArcadeMode.math:
        if (_mathOptions.isEmpty) { final a = 10 + random.nextInt(40); final b = 2 + random.nextInt(9); _specialSecret = a; _mathAddend = b; final correct = a + b; _mathOptions = [correct, correct + 2, correct - 3, correct + 5]..shuffle(random); _mathCorrect = _mathOptions.indexOf(correct); }
        final q = '$_specialSecret + $_mathAddend = ؟';
        _renderOptions(canvas, q, _mathOptions.map((v) => v.toString()).toList()); break;
      case ArcadeMode.word:
        final source = content.prompts.isEmpty ? 'كتاب' : content.prompts[_specialRound % content.prompts.length];
        if (_wordOptions.isEmpty) {
          final distractors = source == 'كتاب'
              ? <String>['قلم', 'باب', 'نهر']
              : source == 'مدرسة'
                  ? <String>['حديقة', 'سيارة', 'نافذة']
                  : source == 'هاتف'
                      ? <String>['مفتاح', 'مصباح', 'حقيبة']
                      : source == 'شجرة'
                          ? <String>['زهرة', 'جبل', 'طريق']
                          : source == 'قمر'
                              ? <String>['شمس', 'نجم', 'بحر']
                              : source == 'مفتاح'
                                  ? <String>['قلم', 'باب', 'كتاب']
                                  : source == 'حديقة'
                                      ? <String>['مدرسة', 'نافذة', 'سيارة']
                                      : <String>['قلم', 'نهر', 'جبل'];
          _wordOptions = <String>[source, ...distractors]..shuffle(random);
          _wordCorrect = _wordOptions.indexOf(source);
        }
        final chars = source.runes.toList()..shuffle(random);
        _renderOptions(canvas, 'رتب: ${String.fromCharCodes(chars)}', _wordOptions); break;
      case ArcadeMode.code: if (_codeDigit < 0) _codeDigit = random.nextInt(4); _renderOptions(canvas, 'اختر الرقم الصحيح لكسر الشفرة', ['0','1','2','3']); break;
      case ArcadeMode.lights:
        for (var n = 0; n < 9; n++) { final x = 12 + (n % 3) * ((size.x - 24) / 3); final y = 100.0 + (n ~/ 3) * 68.0; paint.color = _lights[n] ? const Color(0xFFFFD166) : const Color(0xFF17383B); canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, (size.x - 36) / 3, 52), const Radius.circular(12)), paint); } break;
      case ArcadeMode.pairs:
        _renderPairs(canvas, paint);
        break;
      case ArcadeMode.memory:
        _renderMemory(canvas, paint);
        break;
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

  void _tapChoice(Vector2 point) {
    final n = ((point.y - 150) / 62).floor();
    if (n < 0) return;
    final promptIndex =
        content.prompts.isEmpty ? 0 : _specialRound % content.prompts.length;
    final options = content.choicesByPrompt.isNotEmpty &&
            promptIndex < content.choicesByPrompt.length
        ? content.choicesByPrompt[promptIndex]
        : content.options;
    // Ignore taps in unused rows. This matters for true/false questions and
    // short choice lists, where blank space must never count as an answer.
    final visibleCount = math.min(4, options.length);
    if (n >= visibleCount) return;
    final hasAnswer = content.correctAnswers.isNotEmpty &&
        promptIndex < content.correctAnswers.length;
    final correct = hasAnswer ? content.correctAnswers[promptIndex] : -1;
    if (hasAnswer) {
      score = math.max(0, score + (n == correct ? 2 : -1));
    } else {
      score += 1;
    }
    _specialRound++;
    onScore(score);
    _syncScore();
  }

  void _tapMath(Vector2 point) {
    final n = ((point.y - 150) / 62).floor();
    if (n < 0 || n >= _mathOptions.length) return;
    score = math.max(0, score + (n == _mathCorrect ? 3 : -1));
    _specialRound++;
    _specialSecret = 0;
    _mathAddend = 0;
    _mathOptions = const [];
    onScore(score);
    _syncScore();
  }

  void _tapWord(Vector2 point) {
    final n = ((point.y - 150) / 62).floor();
    if (n < 0 || n >= _wordOptions.length) return;
    score = math.max(0, score + (n == _wordCorrect ? 3 : -1));
    _specialRound++;
    _wordOptions = const [];
    onScore(score);
    _syncScore();
  }

  void _tapCode(Vector2 point) {
    final n = ((point.y - 150) / 62).floor();
    if (n < 0 || n > 3) return;
    if (_codeDigit < 0) _codeDigit = random.nextInt(4);
    if (n == _codeDigit) {
      score += 4;
      _codeDigit = random.nextInt(4);
      _codeAttempts = 0;
      _specialRound++;
    } else {
      _codeAttempts++;
      score = math.max(0, score - 1);
      if (_codeAttempts >= 3) {
        _codeDigit = random.nextInt(4);
        _codeAttempts = 0;
        _specialRound++;
      }
    }
    onScore(score);
    _syncScore();
  }
  void _tapLights(Vector2 point) { if (point.y < 100) return; final col = ((point.x - 8) / ((size.x - 24) / 3)).floor(); final row = ((point.y - 100) / 68).floor(); if (row < 0 || row > 2 || col < 0 || col > 2) return; final n = row * 3 + col; for (final j in [n, n - 1, n + 1, n - 3, n + 3]) { if (j >= 0 && j < 9 && (j ~/ 3 == row || j % 3 == col)) _lights[j] = !_lights[j]; } if (_lights.every((v) => !v)) { score += 5; for (var k = 0; k < 9; k++) _lights[k] = true; onScore(score); _syncScore(); } }
  Rect _squareBoardRect() {
    final side = math.max(1.0, math.min(size.x - 40, size.y - 220));
    return Rect.fromLTWH(
      (size.x - side) / 2,
      math.max(100.0, (size.y - side) / 2),
      side,
      side,
    );
  }

  Rect _fourBoardRect() {
    final availableHeight = math.max(80.0, size.y - 180);
    final width = math.max(1.0, math.min(size.x - 32, availableHeight * 7 / 6));
    final height = width * 6 / 7;
    return Rect.fromLTWH((size.x - width) / 2, math.max(100.0, (size.y - height) / 2), width, height);
  }

  void _drawBoardLabel(Canvas canvas, String text, double y) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.rtl,
    )..layout(maxWidth: size.x - 24);
    painter.paint(canvas, Offset((size.x - painter.width) / 2, y));
  }

  void _renderXo(Canvas canvas, Paint paint) {
    final rect = _squareBoardRect();
    final cell = rect.width / 3;
    final status = _xoWinner == 3
        ? 'تعادل — اضغط أعلى الشاشة لجولة جديدة'
        : _xoWinner != 0
            ? 'فاز اللاعب $_xoWinner — اضغط أعلى الشاشة لجولة جديدة'
            : _isMultiplayerSession
                ? (_canPlayTurn ? 'دورك الآن' : 'بانتظار حركة الخصم')
                : 'دور اللاعب $_xoTurn';
    _drawBoardLabel(canvas, status, rect.top - 24);
    for (var index = 0; index < 9; index++) {
      final row = index ~/ 3;
      final column = index % 3;
      final tile = Rect.fromLTWH(rect.left + column * cell, rect.top + row * cell, cell, cell);
      paint
        ..style = PaintingStyle.fill
        ..color = const Color(0xFF123438);
      canvas.drawRRect(RRect.fromRectAndRadius(tile.deflate(3), const Radius.circular(12)), paint);
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF39D5C5);
      canvas.drawRRect(RRect.fromRectAndRadius(tile.deflate(3), const Radius.circular(12)), paint);
      final marker = _xoBoard[index];
      if (marker == 1) {
        final center = tile.center;
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(4.0, cell * .045)
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF43D9C5);
        canvas.drawLine(
          Offset(center.dx - cell * .22, center.dy - cell * .22),
          Offset(center.dx + cell * .22, center.dy + cell * .22),
          paint,
        );
        canvas.drawLine(
          Offset(center.dx + cell * .22, center.dy - cell * .22),
          Offset(center.dx - cell * .22, center.dy + cell * .22),
          paint,
        );
      } else if (marker == 2) {
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(4.0, cell * .045)
          ..color = const Color(0xFFFFC857);
        canvas.drawCircle(tile.center, cell * .23, paint);
      }
    }
    paint.style = PaintingStyle.fill;
  }

  void _renderFourInRow(Canvas canvas, Paint paint) {
    final rect = _fourBoardRect();
    final cell = rect.width / 7;
    _drawBoardLabel(
      canvas,
      _fourWinner == 3
          ? 'تعادل — اضغط أعلى الشاشة لجولة جديدة'
          : _fourWinner != 0
              ? 'فاز اللاعب $_fourWinner — اضغط أعلى الشاشة لجولة جديدة'
              : _isMultiplayerSession
                  ? (_canPlayTurn ? 'اختر عمودًا في دورك' : 'بانتظار الخصم')
                  : 'دور اللاعب $_fourTurn — اختر عمودًا',
      rect.top - 24,
    );
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF12445B);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(18)), paint);
    for (var row = 0; row < 6; row++) {
      for (var column = 0; column < 7; column++) {
        final marker = _fourBoard[row * 7 + column];
        final center = Offset(rect.left + (column + .5) * cell, rect.top + (row + .5) * cell);
        paint.color = marker == 1
            ? const Color(0xFF40D8C4)
            : marker == 2
                ? const Color(0xFFFFC857)
                : const Color(0xFF08232B);
        canvas.drawCircle(center, cell * .38, paint);
        if (marker != 0) {
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white.withOpacity(.65);
          canvas.drawCircle(center, cell * .38, paint);
          paint.style = PaintingStyle.fill;
        }
      }
    }
  }

  void _renderDotsAndBoxes(Canvas canvas, Paint paint) {
    final rect = _squareBoardRect();
    final cell = rect.width / 3;
    _drawBoardLabel(
      canvas,
      _dotsFinished
          ? 'اكتملت المربعات'
          : _isMultiplayerSession
              ? (_canPlayTurn ? 'ارسم خطًا في دورك' : 'بانتظار الخصم')
              : 'دور اللاعب $_dotsTurn — صِل بين نقطتين',
      rect.top - 24,
    );
    for (var row = 0; row < 3; row++) {
      for (var column = 0; column < 3; column++) {
        final owner = _dotsBoxOwners[row * 3 + column];
        if (owner == 0) continue;
        paint
          ..style = PaintingStyle.fill
          ..color = owner == 1 ? const Color(0x5539D5C5) : const Color(0x55FFC857);
        canvas.drawRect(
          Rect.fromLTWH(rect.left + column * cell + 5, rect.top + row * cell + 5, cell - 10, cell - 10),
          paint,
        );
        _drawCenteredText(
          canvas,
          owner == 1 ? '1' : '2',
          Offset(rect.left + (column + .5) * cell, rect.top + (row + .5) * cell),
          const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
        );
      }
    }
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (var row = 0; row < 4; row++) {
      for (var column = 0; column < 3; column++) {
        if (!_dotsHorizontal[row * 3 + column]) continue;
        paint.color = const Color(0xFF39D5C5);
        canvas.drawLine(
          Offset(rect.left + column * cell, rect.top + row * cell),
          Offset(rect.left + (column + 1) * cell, rect.top + row * cell),
          paint,
        );
      }
    }
    for (var row = 0; row < 3; row++) {
      for (var column = 0; column < 4; column++) {
        if (!_dotsVertical[row * 4 + column]) continue;
        paint.color = const Color(0xFFFFC857);
        canvas.drawLine(
          Offset(rect.left + column * cell, rect.top + row * cell),
          Offset(rect.left + column * cell, rect.top + (row + 1) * cell),
          paint,
        );
      }
    }
    paint
      ..style = PaintingStyle.fill
      ..color = Colors.white;
    for (var row = 0; row < 4; row++) {
      for (var column = 0; column < 4; column++) {
        canvas.drawCircle(Offset(rect.left + column * cell, rect.top + row * cell), 5, paint);
      }
    }
  }

  void _renderPicturePuzzle(Canvas canvas, Paint paint) {
    _ensurePicturePuzzle();
    final rect = _squareBoardRect();
    final cell = rect.width / 4;
    _drawBoardLabel(canvas, _pictureSolved ? 'أحسنت! اكتملت الصورة' : 'رتّب الأرقام من 1 إلى 15', rect.top - 24);
    for (var index = 0; index < 16; index++) {
      final row = index ~/ 4;
      final column = index % 4;
      final tile = Rect.fromLTWH(rect.left + column * cell, rect.top + row * cell, cell, cell);
      final value = _pictureTiles[index];
      paint
        ..style = PaintingStyle.fill
        ..color = value == 0 ? const Color(0xFF071719) : palette[(value - 1) % palette.length];
      canvas.drawRRect(RRect.fromRectAndRadius(tile.deflate(3), const Radius.circular(10)), paint);
      if (value != 0) {
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white.withOpacity(.7);
        canvas.drawRRect(RRect.fromRectAndRadius(tile.deflate(3), const Radius.circular(10)), paint);
        _drawCenteredText(
          canvas,
          value.toString(),
          tile.center,
          const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900),
        );
      }
    }
    paint.style = PaintingStyle.fill;
  }

  void _renderSudoku(Canvas canvas, Paint paint) {
    final rect = _squareBoardRect();
    final cell = rect.width / 4;
    _drawBoardLabel(canvas, _sudokuSolved ? 'تم حل السودوكو!' : 'املأ الخانات بالأرقام من 1 إلى 4', rect.top - 24);
    for (var index = 0; index < 16; index++) {
      final row = index ~/ 4;
      final column = index % 4;
      final tile = Rect.fromLTWH(rect.left + column * cell, rect.top + row * cell, cell, cell);
      final fixed = _sudokuPuzzle[index] != 0;
      paint
        ..style = PaintingStyle.fill
        ..color = fixed ? const Color(0xFF245C59) : const Color(0xFF123438);
      canvas.drawRect(tile, paint);
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = row % 2 == 0 && column % 2 == 0 ? 2.5 : 1
        ..color = const Color(0xFF70BDB4);
      canvas.drawRect(tile, paint);
      final value = _sudokuValues[index];
      if (value != 0) {
        _drawCenteredText(
          canvas,
          value.toString(),
          tile.center,
          TextStyle(
            color: fixed ? Colors.white : const Color(0xFFB3F55A),
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        );
      }
    }
    paint.style = PaintingStyle.fill;
  }

  void _drawCenteredText(Canvas canvas, String text, Offset center, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(center.dx - painter.width / 2, center.dy - painter.height / 2));
  }

  void _ensurePicturePuzzle() {
    if (_pictureTiles.isNotEmpty) return;
    _pictureTiles.addAll(
      GameBoardRules.scramblePicture(seed: (gameId ?? type.name).hashCode),
    );
  }

  void _renderPairs(Canvas canvas, Paint paint) {
    switch (type) {
      case GameType.fourInRow:
        _renderFourInRow(canvas, paint);
        return;
      case GameType.dotsAndBoxes:
        _renderDotsAndBoxes(canvas, paint);
        return;
      case GameType.picturePuzzle:
        _renderPicturePuzzle(canvas, paint);
        return;
      case GameType.sudokuDuel:
        _renderSudoku(canvas, paint);
        return;
      default:
        break;
    }
    if (_pairOrder.isEmpty) _pairOrder.addAll(List<int>.generate(16, (i) => i ~/ 2)..shuffle(random));
    final w = (size.x - 36) / 4;
    for (var n = 0; n < 16; n++) {
      final x = 8 + (n % 4) * w;
      final y = 105.0 + (n ~/ 4) * 60.0;
      final visible = _pairMatched.contains(n) || n == _pairFirst;
      paint.color = visible ? palette[_pairOrder[n] % palette.length] : const Color(0xFF17383B);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w - 5, 52), const Radius.circular(10)), paint);
      if (visible) {
        final t = TextPainter(text: TextSpan(text: (_pairOrder[n] + 1).toString(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)), textDirection: TextDirection.ltr)..layout();
        t.paint(canvas, Offset(x + (w - 5 - t.width) / 2, y + 14));
      }
    }
  }

  void _tapXo(Vector2 point) {
    if (_xoWinner != 0) {
      if (point.y < 100 && _canPlayTurn) {
        _xoBoard.fillRange(0, _xoBoard.length, 0);
        _xoWinner = 0;
        _xoTurn = 1;
        _specialRound++;
        _syncBoardState({'xoBoard': _xoBoard, 'xoWinner': 0});
        onScore(score);
      }
      return;
    }
    if (!_canPlayTurn) return;
    final rect = _squareBoardRect();
    if (!rect.contains(Offset(point.x, point.y))) return;
    final cell = rect.width / 3;
    final column = ((point.x - rect.left) / cell).floor();
    final row = ((point.y - rect.top) / cell).floor();
    if (row < 0 || row >= 3 || column < 0 || column >= 3) return;
    final index = row * 3 + column;
    if (_xoBoard[index] != 0) return;
    final marker = _localMarker(_xoTurn);
    if (marker == 0) return;
    _xoBoard[index] = marker;
    _xoWinner = GameBoardRules.findWinner(
      _xoBoard,
      rows: 3,
      columns: 3,
      runLength: 3,
    );
    if (_xoWinner == 0 && _xoBoard.every((value) => value != 0)) {
      _xoWinner = 3;
    }
    if (_xoWinner == marker) score += 3;
    if (_xoWinner == 0 && !_isMultiplayerSession) _xoTurn = 3 - _xoTurn;
    _specialRound++;
    onScore(score);
    final nextTurn = _xoWinner == 0 ? _nextTurnUid() : null;
    _syncBoardState(
      {'xoBoard': _xoBoard, 'xoWinner': _xoWinner},
      currentTurn: nextTurn,
    );
  }

  void _tapFourInRow(Vector2 point) {
    if (_fourWinner != 0) {
      if (point.y < 100 && _canPlayTurn) {
        _fourBoard.fillRange(0, _fourBoard.length, 0);
        _fourWinner = 0;
        _fourTurn = 1;
        _specialRound++;
        _syncBoardState({'fourBoard': _fourBoard, 'fourWinner': 0});
      }
      return;
    }
    if (!_canPlayTurn) return;
    final rect = _fourBoardRect();
    if (!rect.contains(Offset(point.x, point.y))) return;
    final cell = rect.width / 7;
    final column = ((point.x - rect.left) / cell).floor();
    if (column < 0 || column >= 7) return;
    var target = -1;
    for (var row = 5; row >= 0; row--) {
      final index = row * 7 + column;
      if (_fourBoard[index] == 0) {
        target = index;
        break;
      }
    }
    if (target < 0) return;
    final marker = _localMarker(_fourTurn);
    if (marker == 0) return;
    _fourBoard[target] = marker;
    _fourWinner = GameBoardRules.findWinner(
      _fourBoard,
      rows: 6,
      columns: 7,
      runLength: 4,
    );
    if (_fourWinner == 0 && _fourBoard.every((value) => value != 0)) {
      _fourWinner = 3;
    }
    if (_fourWinner == marker) score += 3;
    if (_fourWinner == 0 && !_isMultiplayerSession) _fourTurn = 3 - _fourTurn;
    _specialRound++;
    onScore(score);
    _syncBoardState(
      {'fourBoard': _fourBoard, 'fourWinner': _fourWinner},
      currentTurn: _fourWinner == 0 ? _nextTurnUid() : null,
    );
  }

  bool _claimDotBox(int row, int column, int marker) {
    final index = row * 3 + column;
    if (_dotsBoxOwners[index] != 0) return false;
    if (!GameBoardRules.dotsBoxComplete(
      row: row,
      column: column,
      horizontal: _dotsHorizontal,
      vertical: _dotsVertical,
    )) {
      return false;
    }
    _dotsBoxOwners[index] = marker;
    return true;
  }

  void _tapDotsAndBoxes(Vector2 point) {
    if (_dotsFinished) {
      if (point.y < 100 && _canPlayTurn) {
        _dotsHorizontal.fillRange(0, _dotsHorizontal.length, false);
        _dotsVertical.fillRange(0, _dotsVertical.length, false);
        _dotsBoxOwners.fillRange(0, _dotsBoxOwners.length, 0);
        _dotsFinished = false;
        _dotsTurn = 1;
        _specialRound++;
        _syncBoardState({
          'dotsHorizontal': _dotsHorizontal,
          'dotsVertical': _dotsVertical,
          'dotsBoxOwners': _dotsBoxOwners,
          'dotsFinished': false,
        }, currentTurn: _localUid);
      }
      return;
    }
    if (!_canPlayTurn) return;
    final rect = _squareBoardRect();
    if (!rect.inflate(18).contains(Offset(point.x, point.y))) return;
    final cell = rect.width / 3;
    var bestDistance = double.infinity;
    var horizontalIndex = -1;
    var verticalIndex = -1;

    for (var row = 0; row < 4; row++) {
      for (var column = 0; column < 3; column++) {
        final index = row * 3 + column;
        if (_dotsHorizontal[index]) continue;
        final center = Offset(rect.left + (column + .5) * cell, rect.top + row * cell);
        final distance = center.distanceTo(Offset(point.x, point.y));
        if (distance < bestDistance) {
          bestDistance = distance;
          horizontalIndex = index;
          verticalIndex = -1;
        }
      }
    }
    for (var row = 0; row < 3; row++) {
      for (var column = 0; column < 4; column++) {
        final index = row * 4 + column;
        if (_dotsVertical[index]) continue;
        final center = Offset(rect.left + column * cell, rect.top + (row + .5) * cell);
        final distance = center.distanceTo(Offset(point.x, point.y));
        if (distance < bestDistance) {
          bestDistance = distance;
          horizontalIndex = -1;
          verticalIndex = index;
        }
      }
    }
    if (bestDistance > cell * .23) return;
    final marker = _localMarker(_dotsTurn);
    if (marker == 0) return;
    var capturedCount = 0;
    if (horizontalIndex >= 0) {
      _dotsHorizontal[horizontalIndex] = true;
      final row = horizontalIndex ~/ 3;
      final column = horizontalIndex % 3;
      if (row > 0 && _claimDotBox(row - 1, column, marker)) capturedCount++;
      if (row < 3 && _claimDotBox(row, column, marker)) capturedCount++;
    } else if (verticalIndex >= 0) {
      _dotsVertical[verticalIndex] = true;
      final row = verticalIndex ~/ 4;
      final column = verticalIndex % 4;
      if (column > 0 && _claimDotBox(row, column - 1, marker)) capturedCount++;
      if (column < 3 && _claimDotBox(row, column, marker)) capturedCount++;
    } else {
      return;
    }

    final captured = capturedCount > 0;
    if (captured) score += capturedCount;
    _dotsFinished = _dotsBoxOwners.every((owner) => owner != 0);
    if (!captured && !_dotsFinished && !_isMultiplayerSession) {
      _dotsTurn = 3 - _dotsTurn;
    }
    _specialRound++;
    onScore(score);
    _syncBoardState(
      {
        'dotsHorizontal': _dotsHorizontal,
        'dotsVertical': _dotsVertical,
        'dotsBoxOwners': _dotsBoxOwners,
        'dotsFinished': _dotsFinished,
      },
      currentTurn: captured ? _localUid : (_dotsFinished ? null : _nextTurnUid()),
    );
  }

  void _tapPicturePuzzle(Vector2 point) {
    if (_pictureSolved) return;
    _ensurePicturePuzzle();
    final rect = _squareBoardRect();
    if (!rect.contains(Offset(point.x, point.y))) return;
    final cell = rect.width / 4;
    final column = ((point.x - rect.left) / cell).floor();
    final row = ((point.y - rect.top) / cell).floor();
    if (row < 0 || row >= 4 || column < 0 || column >= 4) return;
    final index = row * 4 + column;
    final blank = _pictureTiles.indexOf(0);
    if (blank < 0) return;
    final blankRow = blank ~/ 4;
    final blankColumn = blank % 4;
    if ((row - blankRow).abs() + (column - blankColumn).abs() != 1) return;
    _pictureTiles[blank] = _pictureTiles[index];
    _pictureTiles[index] = 0;
    _pictureSolved = GameBoardRules.isSolvedPicture(_pictureTiles);
    if (_pictureSolved) score += 10;
    _specialRound++;
    onScore(score);
    _syncBoardState({
      'pictureTiles': _pictureTiles,
      'pictureSolved': _pictureSolved,
    });
  }

  void _tapSudoku(Vector2 point) {
    if (_sudokuSolved || !_canPlayTurn) return;
    final rect = _squareBoardRect();
    if (!rect.contains(Offset(point.x, point.y))) return;
    final cell = rect.width / 4;
    final column = ((point.x - rect.left) / cell).floor();
    final row = ((point.y - rect.top) / cell).floor();
    if (row < 0 || row >= 4 || column < 0 || column >= 4) return;
    final index = row * 4 + column;
    if (_sudokuPuzzle[index] != 0) return;
    final oldValue = _sudokuValues[index];
    var foundValidValue = false;
    for (var attempt = 0; attempt < 5; attempt++) {
      _sudokuValues[index] = (_sudokuValues[index] + 1) % 5;
      if (GameBoardRules.isValidSudoku4x4(
        _sudokuValues,
        requireComplete: false,
      )) {
        foundValidValue = true;
        break;
      }
    }
    if (!foundValidValue) {
      _sudokuValues[index] = oldValue;
      score = math.max(0, score - 1);
      onScore(score);
      _syncBoardState({'sudokuValues': _sudokuValues}, currentTurn: _localUid);
      return;
    }
    _sudokuSolved = GameBoardRules.isValidSudoku4x4(_sudokuValues);
    if (_sudokuSolved) score += 10;
    if (!_isMultiplayerSession && !_sudokuSolved) _sudokuTurn = 3 - _sudokuTurn;
    _specialRound++;
    onScore(score);
    _syncBoardState(
      {'sudokuValues': _sudokuValues, 'sudokuSolved': _sudokuSolved},
      currentTurn: _sudokuSolved ? null : _nextTurnUid(),
    );
  }

  void _tapPairs(Vector2 point) {
    switch (type) {
      case GameType.fourInRow:
        _tapFourInRow(point);
        return;
      case GameType.dotsAndBoxes:
        _tapDotsAndBoxes(point);
        return;
      case GameType.picturePuzzle:
        _tapPicturePuzzle(point);
        return;
      case GameType.sudokuDuel:
        _tapSudoku(point);
        return;
      default:
        break;
    }
    if (point.y < 100) return;
    if (_pairOrder.isEmpty) _pairOrder.addAll(List<int>.generate(16, (i) => i ~/ 2)..shuffle(random));
    final cellWidth = (size.x - 36) / 4;
    final col = ((point.x - 8) / cellWidth).floor();
    final row = ((point.y - 105) / 60).floor();
    if (col < 0 || col >= 4 || row < 0 || row >= 4) return;
    final cell = row * 4 + col;
    if (_pairMatched.contains(cell) || cell == _pairFirst) return;
    if (_pairFirst < 0) {
      _pairFirst = cell;
      return;
    }
    if (_pairOrder[_pairFirst] == _pairOrder[cell]) {
      _pairMatched.addAll([_pairFirst, cell]);
      score += 2;
    } else {
      score = math.max(0, score - 1);
    }
    _pairFirst = -1;
    onScore(score);
    _syncScore();
  }
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
        state: {'score': score, 'action': 'arcade_hit', 'gameType': type.name, 'round': _specialRound},
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


class _Point3 {
  const _Point3(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;
}
