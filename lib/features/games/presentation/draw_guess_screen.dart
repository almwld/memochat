import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/game.dart';
import '../models/game_session.dart';
import '../services/game_service.dart';

/// Real multiplayer drawing/guessing round. Strokes are stored as normalized
/// coordinates so devices with different screen sizes can render the same art.
class DrawGuessScreen extends StatefulWidget {
  const DrawGuessScreen({
    super.key,
    required this.chatId,
    required this.gameId,
  });

  final String chatId;
  final String gameId;

  @override
  State<DrawGuessScreen> createState() => _DrawGuessScreenState();
}

class _DrawGuessScreenState extends State<DrawGuessScreen> {
  static const _words = <String>[
    'بيت', 'شمس', 'قمر', 'سيارة', 'شجرة', 'قطة', 'كتاب', 'سمكة',
  ];
  static const _colors = <Color>[
    Color(0xFF0D8274), Color(0xFFE45757), Color(0xFF3978D4),
    Color(0xFF8A56C7), Color(0xFF263238),
  ];

  StreamSubscription<GameSession?>? _subscription;
  final List<_Stroke> _strokes = <_Stroke>[];
  final List<Offset> _draft = <Offset>[];
  List<String> _players = <String>[];
  String _word = '';
  String? _drawerUid;
  String? _message;
  int _round = 0;
  int _score = 0;
  int _remoteScore = 0;
  int _colorIndex = 0;
  bool _solved = false;
  bool _initialized = false;
  bool _saving = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  bool get _isDrawer => _uid != null && _drawerUid == _uid;

  @override
  void initState() {
    super.initState();
    _subscription = GameService.instance
        .watchGame(widget.chatId, widget.gameId)
        .listen(_onSession, onError: (_) {
      if (mounted) setState(() => _message = 'تعذرت مزامنة الرسم. تحقق من الاتصال.');
    });
  }

  void _onSession(GameSession? session) {
    if (!mounted || session == null) return;
    final uid = _uid;
    final others = session.players.where((id) => id != uid).toList();
    final state = session.state;
    final rawStrokes = state['strokes'];
    setState(() {
      _players = List<String>.from(session.players);
      _drawerUid = state['drawerUid'] as String? ??
          (session.players.isNotEmpty ? session.players.first : null);
      _round = (state['round'] as num?)?.toInt() ?? _round;
      _word = state['word'] as String? ?? _word;
      _solved = state['solved'] == true;
      _remoteScore = others.isEmpty ? 0 : (session.scores[others.first] ?? 0);
      if (uid != null) _score = session.scores[uid] ?? _score;
      if (rawStrokes is List) {
        _strokes
          ..clear()
          ..addAll(rawStrokes.whereType<Map>().map(_Stroke.fromMap));
      }
      _initialized = _word.isNotEmpty && _drawerUid != null;
    });
    if (!_initialized &&
        uid != null &&
        session.status == GameStatus.playing &&
        session.players.isNotEmpty &&
        uid == session.players.first) {
      _startRound(0, session.players.first);
    }
  }

  Future<void> _startRound(int round, String drawerUid) async {
    if (_saving || _uid == null) return;
    setState(() => _saving = true);
    final word = _words[round % _words.length];
    try {
      await GameService.instance.updatePlayerState(
        chatId: widget.chatId,
        gameId: widget.gameId,
        uid: _uid!,
        score: _score,
        currentTurn: drawerUid,
        state: {
          'round': round,
          'word': word,
          'drawerUid': drawerUid,
          'strokes': <Map<String, dynamic>>[],
          'solved': false,
          'action': 'draw_round_started',
        },
      );
    } catch (_) {
      if (mounted) setState(() => _message = 'تعذر بدء الجولة؛ أعد المحاولة.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<Map<String, dynamic>> _serializedStrokes() => _strokes
      .map((stroke) => <String, dynamic>{
            'color': stroke.colorIndex,
            'points': stroke.points
                .map((p) => <double>[p.dx, p.dy])
                .toList(),
          })
      .toList();

  Future<void> _saveDrawing({bool clear = false}) async {
    if (_uid == null || _saving || !_isDrawer) return;
    setState(() => _saving = true);
    try {
      await GameService.instance.updatePlayerState(
        chatId: widget.chatId,
        gameId: widget.gameId,
        uid: _uid!,
        score: _score,
        currentTurn: _drawerUid,
        state: {
          'strokes': _serializedStrokes(),
          'round': _round,
          'word': _word,
          'drawerUid': _drawerUid,
          'solved': _solved,
          'action': clear ? 'drawing_cleared' : 'drawing_updated',
        },
      );
    } catch (_) {
      if (mounted) setState(() => _message = 'لم يُحفظ الرسم؛ حاول مجددًا.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> get _guessOptions {
    final answer = _word;
    final distractors = _words.where((word) => word != answer).toList();
    final start = _round % distractors.length;
    final choices = <String>[
      answer,
      distractors[start],
      distractors[(start + 2) % distractors.length],
      distractors[(start + 4) % distractors.length],
    ];
    final shift = _round % choices.length;
    return List<String>.generate(choices.length, (i) => choices[(i + shift) % choices.length]);
  }

  Future<void> _guess(String guess) async {
    if (_uid == null || _isDrawer || _solved || _saving || _word.isEmpty) return;
    if (guess != _word) {
      setState(() => _message = 'ليست الإجابة الصحيحة، حاول مرة أخرى.');
      return;
    }
    final nextRound = _round + 1;
    final nextDrawer = _players.length < 2
        ? _uid!
        : (_drawerUid == _players.first ? _players.last : _players.first);
    setState(() {
      _saving = true;
      _score += 3;
      _message = 'إجابة صحيحة! +3 نقاط';
      _solved = true;
    });
    try {
      await GameService.instance.updatePlayerState(
        chatId: widget.chatId,
        gameId: widget.gameId,
        uid: _uid!,
        score: _score,
        currentTurn: nextDrawer,
        state: {
          'round': nextRound,
          'word': _words[nextRound % _words.length],
          'drawerUid': nextDrawer,
          'strokes': <Map<String, dynamic>>[],
          'solved': false,
          'action': 'correct_guess',
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _solved = false;
          _message = 'الإجابة صحيحة، لكن تعذر حفظ النتيجة.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _beginStroke(Offset local, Size size) {
    if (!_isDrawer || _solved || size.width <= 0 || size.height <= 0) return;
    setState(() {
      _draft
        ..clear()
        ..add(Offset(
          (local.dx / size.width).clamp(0.0, 1.0).toDouble(),
          (local.dy / size.height).clamp(0.0, 1.0).toDouble(),
        ));
    });
  }

  void _extendStroke(Offset local, Size size) {
    if (!_isDrawer || _solved || size.width <= 0 || size.height <= 0) return;
    setState(() {
      _draft.add(Offset(
        (local.dx / size.width).clamp(0.0, 1.0),
        (local.dy / size.height).clamp(0.0, 1.0),
      ));
    });
  }

  Future<void> _finishStroke() async {
    if (_draft.isEmpty) return;
    setState(() {
      _strokes.add(_Stroke(
        points: List<Offset>.from(_draft),
        colorIndex: _colorIndex,
      ));
      _draft.clear();
    });
    await _saveDrawing();
  }

  Future<void> _clearDrawing() async {
    if (!_isDrawer || _solved) return;
    setState(() {
      _strokes.clear();
      _draft.clear();
      _message = null;
    });
    await _saveDrawing(clear: true);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('ارسم وخمّن'), centerTitle: true),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  Expanded(child: _scoreCard('أنت', _score, theme.colorScheme.primary)),
                  const SizedBox(width: 10),
                  Expanded(child: _scoreCard('الخصم', _remoteScore, theme.colorScheme.secondary)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                !_initialized
                    ? 'جاري تجهيز جولة الرسم…'
                    : _solved
                        ? 'تم حل الكلمة، يجري تجهيز الجولة التالية'
                        : _isDrawer
                            ? 'ارسم الكلمة التالية: $_word'
                            : 'اختر الكلمة التي يعبّر عنها الرسم',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(_message!, textAlign: TextAlign.center),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? const Color(0xFF10201E)
                          : const Color(0xFFF8FBFA),
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: LayoutBuilder(builder: (context, constraints) {
                      final size = Size(constraints.maxWidth, constraints.maxHeight);
                      return GestureDetector(
                        onPanStart: (event) => _beginStroke(event.localPosition, size),
                        onPanUpdate: (event) => _extendStroke(event.localPosition, size),
                        onPanEnd: (_) => _finishStroke(),
                        child: CustomPaint(
                          painter: _DrawingPainter(
                            strokes: _strokes,
                            draft: _draft,
                            draftColor: _colors[_colorIndex],
                          ),
                          child: const SizedBox.expand(),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
            if (_isDrawer && !_solved)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Row(
                  children: [
                    for (var i = 0; i < _colors.length; i++)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: InkWell(
                          onTap: () => setState(() => _colorIndex = i),
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: _colors[i],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _colorIndex == i ? theme.colorScheme.onSurface : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'مسح الرسم',
                      onPressed: _saving ? null : _clearDrawing,
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ),
            if (!_isDrawer && !_solved && _word.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: _guessOptions.map((option) => FilledButton.tonal(
                    onPressed: _saving ? null : () => _guess(option),
                    child: Text(option),
                  )).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _scoreCard(String label, int value, Color color) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: color.withOpacity(.10),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(.2)),
        ),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
          Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        ]),
      );
}

class _Stroke {
  const _Stroke({required this.points, required this.colorIndex});

  final List<Offset> points;
  final int colorIndex;

  factory _Stroke.fromMap(Map raw) {
    final rawPoints = raw['points'];
    final points = <Offset>[];
    if (rawPoints is List) {
      for (final item in rawPoints) {
        if (item is List && item.length >= 2 && item[0] is num && item[1] is num) {
          points.add(Offset((item[0] as num).toDouble(), (item[1] as num).toDouble()));
        }
      }
    }
    final color = raw['color'] is num ? (raw['color'] as num).toInt() : 0;
    return _Stroke(points: points, colorIndex: color.clamp(0, 4).toInt());
  }
}

class _DrawingPainter extends CustomPainter {
  const _DrawingPainter({
    required this.strokes,
    required this.draft,
    required this.draftColor,
  });

  final List<_Stroke> strokes;
  final List<Offset> draft;
  final Color draftColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      paint.color = _DrawingPainter._color(stroke.colorIndex);
      _drawStroke(canvas, size, stroke.points, paint);
    }
    if (draft.isNotEmpty) {
      paint.color = draftColor;
      _drawStroke(canvas, size, draft, paint);
    }
  }

  void _drawStroke(Canvas canvas, Size size, List<Offset> points, Paint paint) {
    if (points.length == 1) {
      canvas.drawCircle(Offset(points.first.dx * size.width, points.first.dy * size.height), 2, paint);
      return;
    }
    final path = Path();
    path.moveTo(points.first.dx * size.width, points.first.dy * size.height);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx * size.width, point.dy * size.height);
    }
    canvas.drawPath(path, paint);
  }

  static Color _color(int index) => _DrawGuessScreenState._colors[index.clamp(0, 4).toInt()];

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) => true;
}
