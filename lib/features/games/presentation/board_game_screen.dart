import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/game.dart';
import '../../models/game_session.dart';
import '../../services/game_service.dart';

/// Purpose-built board mechanics for games that must not fall back to the
/// generic arcade target-tapping runtime.
class BoardGameScreen extends StatefulWidget {
  const BoardGameScreen({
    super.key,
    required this.type,
    this.chatId = '',
    this.gameId,
  });

  final GameType type;
  final String chatId;
  final String? gameId;

  @override
  State<BoardGameScreen> createState() => _BoardGameScreenState();
}

class _BoardGameScreenState extends State<BoardGameScreen> {
  final _random = math.Random();
  StreamSubscription<GameSession?>? _subscription;
  List<int> _board = <int>[];
  List<int> _edges = <int>[];
  List<int> _boxes = <int>[];
  List<int> _pairValues = <int>[];
  Set<int> _revealed = <int>{};
  Set<int> _matched = <int>{};
  int? _firstPair;
  int _score = 0;
  int _remoteScore = 0;
  int _moves = 0;
  int _turnIndex = 0;
  int _localMark = 1;
  int _round = 0;
  bool _finished = false;
  String? _winnerUid;
  List<String> _players = <String>[];
  String? _turnUid;
  String? _status;
  String? _message;
  bool _busy = false;

  bool get _multiplayer =>
      widget.chatId.trim().isNotEmpty &&
      (widget.gameId?.trim().isNotEmpty ?? false);
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  bool get _myTurn => !_multiplayer || _turnUid == null || _turnUid == _uid;

  String get _title => switch (widget.type) {
        GameType.xo => 'إكس أو',
        GameType.fourInRow => 'أربع متتالية',
        GameType.dotsAndBoxes => 'وصل النقاط',
        GameType.sudokuDuel => 'سودوكو ٤×٤',
        GameType.picturePuzzle => 'لغز الصورة',
        GameType.connectPairs => 'وصل الأزواج',
        _ => 'لعبة اللوحة',
      };

  @override
  void initState() {
    super.initState();
    _resetLocalBoard();
    if (_multiplayer) _watchSession();
  }

  void _resetLocalBoard() {
    switch (widget.type) {
      case GameType.xo:
        _board = List<int>.filled(9, 0);
        _localMark = 1;
        break;
      case GameType.fourInRow:
        _board = List<int>.filled(42, 0);
        break;
      case GameType.dotsAndBoxes:
        _edges = List<int>.filled(24, 0);
        _boxes = List<int>.filled(9, 0);
        break;
      case GameType.sudokuDuel:
        // A valid 4x4 Latin/Sudoku solution with a small set of fixed clues.
        _board = <int>[1, 0, 0, 4, 0, 4, 1, 0, 0, 1, 4, 0, 4, 0, 0, 1];
        break;
      case GameType.picturePuzzle:
        _board = List<int>.generate(9, (i) => (i + 1) % 9);
        _shufflePuzzle();
        break;
      case GameType.connectPairs:
        _pairValues = List<int>.generate(16, (i) => i ~/ 2)..shuffle(_random);
        _revealed = <int>{};
        _matched = <int>{};
        _firstPair = null;
        break;
      default:
        break;
    }
  }

  void _shufflePuzzle() {
    // Make a solvable board by applying legal moves from the solved state.
    for (var i = 0; i < 100; i++) {
      final blank = _board.indexOf(0);
      final candidates = <int>[
        if (blank % 3 > 0) blank - 1,
        if (blank % 3 < 2) blank + 1,
        if (blank >= 3) blank - 3,
        if (blank < 6) blank + 3,
      ];
      final next = candidates[_random.nextInt(candidates.length)];
      _swap(_board, blank, next);
    }
    if (_isPuzzleSolved) _swap(_board, 0, 1);
  }

  bool get _isPuzzleSolved =>
      _board.length == 9 && List<int>.generate(9, (i) => (i + 1) % 9)
          .asMap().entries.every((e) => _board[e.key] == e.value);

  void _watchSession() {
    _subscription = GameService.instance
        .watchGame(widget.chatId, widget.gameId!.trim())
        .listen((session) {
      if (!mounted || session == null) return;
      final uid = _uid;
      final opponents = session.players.where((id) => id != uid).toList();
      final state = session.state;
      final rawBoard = state['board'];
      final rawEdges = state['edges'];
      final rawBoxes = state['boxes'];
      final rawPairs = state['pairValues'];
      final rawRevealed = state['revealed'];
      final rawMatched = state['matched'];
      setState(() {
        _players = List<String>.from(session.players);
        _turnUid = session.currentTurn ??
            (session.players.isNotEmpty ? session.players.first : null);
        _status = session.status.name;
        _remoteScore = opponents.isEmpty ? 0 : (session.scores[opponents.first] ?? 0);
        if (rawBoard is List && rawBoard.length == _board.length) {
          _board = rawBoard.map((e) => (e as num).toInt()).toList();
        }
        if (rawEdges is List && rawEdges.length == _edges.length) {
          _edges = rawEdges.map((e) => (e as num).toInt()).toList();
        }
        if (rawBoxes is List && rawBoxes.length == _boxes.length) {
          _boxes = rawBoxes.map((e) => (e as num).toInt()).toList();
        }
        if (rawPairs is List && rawPairs.length == 16) {
          _pairValues = rawPairs.map((e) => (e as num).toInt()).toList();
        }
        if (rawRevealed is List) _revealed = rawRevealed.map((e) => (e as num).toInt()).toSet();
        if (rawMatched is List) _matched = rawMatched.map((e) => (e as num).toInt()).toSet();
        final score = uid == null ? null : session.scores[uid];
        if (score != null) _score = score;
        _round = (state['round'] as num?)?.toInt() ?? _round;
        _moves = (state['moves'] as num?)?.toInt() ?? _moves;
        _finished = state['finished'] == true || session.status == GameStatus.ended;
        _winnerUid = state['winnerUid'] as String?;
        _message = state['message'] as String?;
      });
    }, onError: (_) {
      if (mounted) setState(() => _message = 'تعذر مزامنة اللوحة؛ تحقق من الاتصال.');
    });
  }

  Future<void> _publish({String? nextTurn, bool finish = false}) async {
    if (!_multiplayer || _uid == null || _busy) return;
    setState(() => _busy = true);
    try {
      final state = <String, dynamic>{
        'board': _board,
        'edges': _edges,
        'boxes': _boxes,
        'pairValues': _pairValues,
        'revealed': _revealed.toList(),
        'matched': _matched.toList(),
        'round': _round,
        'moves': _moves,
        'finished': _finished,
        'winnerUid': _winnerUid,
        'message': _message,
        'gameType': widget.type.name,
      };
      await GameService.instance.updatePlayerState(
        chatId: widget.chatId,
        gameId: widget.gameId!.trim(),
        uid: _uid!,
        state: state,
        score: _score,
        currentTurn: nextTurn,
      );
      if (finish) {
        final finalScores = <String, int>{};
        if (_uid != null) finalScores[_uid!] = _score;
        for (final player in _players) {
          if (player != _uid) finalScores[player] = _remoteScore;
        }
        await GameService.instance.endGame(
          chatId: widget.chatId,
          gameId: widget.gameId!.trim(),
          scores: finalScores,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ حركة اللعبة. أعد المحاولة عند استقرار الاتصال.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _nextPlayer() {
    if (!_multiplayer || _players.length < 2) return null;
    final current = _turnUid ?? _players.first;
    final index = _players.indexOf(current);
    return _players[(index + 1) % _players.length];
  }

  int _markForPlayer() {
    if (!_multiplayer || _players.length < 2) return _localMark;
    return _uid == _players.first ? 1 : 2;
  }

  void _guard() {
    if (!_myTurn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('انتظر دور اللاعب الآخر')),
      );
    }
  }

  Future<void> _playCell(int index) async {
    if (_finished || _busy) return;
    if (!_myTurn) return _guard();
    setState(() {
      _message = null;
      _moves++;
      switch (widget.type) {
        case GameType.xo:
          if (_board[index] != 0) return;
          _board[index] = _markForPlayer();
          final winner = _winnerInLineBoard(_board, 3, 3, 3);
          if (winner != 0) {
            _finished = true;
            _winnerUid = _multiplayer ? _players[winner - 1] : _uid;
            if (winner == _markForPlayer()) _score += 3;
            _message = winner == _markForPlayer() ? 'فزت بالجولة!' : 'انتهت الجولة.';
          } else if (_board.every((v) => v != 0)) {
            _finished = true;
            _message = 'تعادل!';
          }
          break;
        case GameType.fourInRow:
          final col = index % 7;
          final row = List<int>.generate(6, (r) => r).reversed
              .firstWhere((r) => _board[r * 7 + col] == 0, orElse: () => -1);
          if (row < 0) return;
          _board[row * 7 + col] = _markForPlayer();
          final winner = _winnerInLineBoard(_board, 7, 6, 4);
          if (winner != 0) {
            _finished = true;
            _winnerUid = _multiplayer ? _players[winner - 1] : _uid;
            if (winner == _markForPlayer()) _score += 5;
            _message = winner == _markForPlayer() ? 'أربع متتالية! فزت.' : 'انتهت الجولة.';
          } else if (_board.every((v) => v != 0)) {
            _finished = true;
            _message = 'تعادل!';
          }
          break;
        case GameType.picturePuzzle:
          final blank = _board.indexOf(0);
          if ((index ~/ 3 - blank ~/ 3).abs() + (index % 3 - blank % 3).abs() != 1) return;
          _swap(_board, index, blank);
          if (_isPuzzleSolved) {
            _finished = true;
            _score += math.max(1, 50 - _moves);
            _message = 'أحسنت! أكملت الصورة في $_moves حركة.';
          }
          break;
        case GameType.sudokuDuel:
          if (_board[index] != 0) return;
          _chooseSudokuValue(index);
          return;
        case GameType.connectPairs:
          _tapPair(index);
          return;
        default:
          return;
      }
      if (!_finished) {
        if (_multiplayer) {
          _turnUid = _nextPlayer();
        } else {
          _localMark = _localMark == 1 ? 2 : 1;
        }
      }
    });
    await _publish(nextTurn: _finished ? null : _turnUid, finish: _finished);
  }

  int _winnerInLineBoard(List<int> values, int columns, int rows, int target) {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < columns; c++) {
        final v = values[r * columns + c];
        if (v == 0) continue;
        for (final d in <List<int>>[[1, 0], [0, 1], [1, 1], [1, -1]]) {
          var count = 1;
          for (var step = 1; step < target; step++) {
            final nr = r + d[1] * step;
            final nc = c + d[0] * step;
            if (nr < 0 || nr >= rows || nc < 0 || nc >= columns ||
                values[nr * columns + nc] != v) break;
            count++;
          }
          if (count >= target) return v;
        }
      }
    }
    return 0;
  }

  Future<void> _chooseSudokuValue(int index) async {
    final value = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            children: List.generate(4, (i) => FilledButton(
              onPressed: () => Navigator.pop(context, i + 1),
              child: Text('${i + 1}'),
            )),
          ),
        ),
      ),
    );
    if (!mounted || value == null || !_myTurn) return;
    const solution = <int>[1, 2, 3, 4, 3, 4, 1, 2, 2, 1, 4, 3, 4, 3, 2, 1];
    setState(() {
      _moves++;
      if (solution[index] == value) {
        _board[index] = value;
        _score++;
        _message = 'إجابة صحيحة!';
      } else {
        _message = 'ليست هذه الخانة الصحيحة، حاول مجددًا.';
      }
      if (_board.every((v) => v != 0)) {
        _finished = true;
        _message = 'أكملت شبكة السودوكو!';
      } else if (_multiplayer) {
        _turnUid = _nextPlayer();
      }
    });
    await _publish(nextTurn: _finished ? null : _turnUid, finish: _finished);
  }

  Future<void> _tapPair(int index) async {
    if (_finished || _busy) return;
    if (!_myTurn) return _guard();
    if (_matched.contains(index) || _revealed.contains(index)) return;
    setState(() {
      _revealed.add(index);
      if (_firstPair == null) {
        _firstPair = index;
        _message = null;
        return;
      }
      final first = _firstPair!;
      if (_pairValues[first] == _pairValues[index]) {
        _matched.addAll([first, index]);
        _score += 2;
        _message = 'زوج متطابق!';
      } else {
        _message = 'ليسا متطابقين؛ اضغط متابعة لإخفائهما.';
      }
      _firstPair = null;
      _round++;
      if (_matched.length == _pairValues.length) {
        _finished = true;
        _message = 'أكملت جميع الأزواج!';
      } else if (_multiplayer) {
        _turnUid = _nextPlayer();
      }
    });
    await _publish(nextTurn: _finished ? null : _turnUid, finish: _finished);
  }

  Future<void> _continuePairs() async {
    setState(() {
      _revealed.removeWhere((i) => !_matched.contains(i));
      _message = null;
    });
    await _publish(nextTurn: _turnUid);
  }

  Future<void> _tapDotEdge(Offset local, double side) async {
    if (_finished || !_myTurn || _busy) {
      if (!_myTurn) _guard();
      return;
    }
    const pad = 20.0;
    final step = (side - pad * 2) / 3;
    final x = (local.dx - pad).clamp(0.0, side - pad * 2);
    final y = (local.dy - pad).clamp(0.0, side - pad * 2);
    final col = (x / step).round().clamp(0, 3);
    final row = (y / step).round().clamp(0, 3);
    final dx = (x - col * step).abs();
    final dy = (y - row * step).abs();
    var edgeIndex = -1;
    if (dy <= dx) {
      final segmentCol = (x / step).floor().clamp(0, 2);
      edgeIndex = row * 3 + segmentCol; // horizontal edge
    } else {
      final segmentRow = (y / step).floor().clamp(0, 2);
      edgeIndex = 12 + segmentRow * 4 + col; // vertical edge
    }
    if (edgeIndex < 0 || edgeIndex >= _edges.length || _edges[edgeIndex] != 0) return;
    var earned = 0;
    setState(() {
      _edges[edgeIndex] = _markForPlayer();
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 3; c++) {
          final box = r * 3 + c;
          if (_boxes[box] != 0) continue;
          final top = r * 3 + c;
          final bottom = (r + 1) * 3 + c;
          final left = 12 + r * 4 + c;
          final right = left + 1;
          if (_edges[top] != 0 && _edges[bottom] != 0 &&
              _edges[left] != 0 && _edges[right] != 0) {
            _boxes[box] = _markForPlayer();
            earned++;
          }
        }
      }
      _score += earned * 2;
      _moves++;
      _finished = _edges.every((e) => e != 0);
      if (_finished) _message = 'انتهت اللعبة!';
      if (!_finished && earned == 0 && _multiplayer) _turnUid = _nextPlayer();
    });
    await _publish(nextTurn: _finished ? null : _turnUid, finish: _finished);
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
      appBar: AppBar(title: Text(_title), centerTitle: true),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  Expanded(child: _scoreCard('أنت', _score, theme.colorScheme.primary)),
                  const SizedBox(width: 10),
                  Expanded(child: _scoreCard('الخصم', _remoteScore, theme.colorScheme.secondary)),
                ],
              ),
            ),
            if (_multiplayer) Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _status == 'waiting' ? 'بانتظار اللاعب الآخر'
                    : _status == 'ended' || _finished ? 'انتهت اللعبة'
                    : _myTurn ? 'دورك الآن' : 'دور اللاعب الآخر',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            if (_message != null) Padding(
              padding: const EdgeInsets.all(10),
              child: Text(_message!, textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildBoard(context),
                ),
              ),
            ),
            if (_finished || _message?.contains('ليسا متطابقين') == true)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton.icon(
                  onPressed: _message?.contains('ليسا متطابقين') == true
                      ? _continuePairs
                      : () => setState(() {
                            _score = 0;
                            _remoteScore = 0;
                            _moves = 0;
                            _finished = false;
                            _winnerUid = null;
                            _message = null;
                            _turnUid = _players.isNotEmpty ? _players.first : null;
                            _resetLocalBoard();
                            _localMark = 1;
                            if (_multiplayer) _publish(nextTurn: _turnUid);
                          }),
                  icon: Icon(_finished ? Icons.refresh_rounded : Icons.visibility_off_rounded),
                  label: Text(_finished ? 'العب مجددًا' : 'متابعة'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _scoreCard(String label, int score, Color color) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(.22)),
        ),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
          Text('$score', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        ]),
      );

  Widget _buildBoard(BuildContext context) {
    switch (widget.type) {
      case GameType.xo:
        return AspectRatio(aspectRatio: 1, child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 9,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
          itemBuilder: (_, i) => _cell(
            onTap: () => _playCell(i),
            child: Text(_board[i] == 1 ? 'X' : _board[i] == 2 ? 'O' : '',
                style: TextStyle(fontSize: 46, fontWeight: FontWeight.w900,
                    color: _board[i] == 1 ? const Color(0xFF0D8274) : Colors.deepOrange)),
          ),
        ));
      case GameType.fourInRow:
        return AspectRatio(aspectRatio: 7 / 6, child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: const Color(0xFF1769AA), borderRadius: BorderRadius.circular(18)),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, crossAxisSpacing: 5, mainAxisSpacing: 5),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => _playCell(i),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _board[i] == 1 ? const Color(0xFFFFC857)
                      : _board[i] == 2 ? const Color(0xFFFF5D73) : Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ));
      case GameType.sudokuDuel:
        return AspectRatio(aspectRatio: 1, child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 16,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 4, mainAxisSpacing: 4),
          itemBuilder: (_, i) => _cell(
            onTap: () => _playCell(i),
            child: Text(_board[i] == 0 ? '·' : '${_board[i]}',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
                color: _board[i] == 0 ? Colors.grey : themeColor(context))),
          ),
        ));
      case GameType.picturePuzzle:
        return AspectRatio(aspectRatio: 1, child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 9,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
          itemBuilder: (_, i) => _cell(
            onTap: () => _playCell(i),
            child: _board[i] == 0 ? const SizedBox.shrink() : Text('${_board[i]}',
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
          ),
        ));
      case GameType.connectPairs:
        return AspectRatio(aspectRatio: 1, child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 16,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 6, mainAxisSpacing: 6),
          itemBuilder: (_, i) {
            final visible = _revealed.contains(i) || _matched.contains(i);
            return _cell(
              onTap: () => _tapPair(i),
              child: Text(visible ? String.fromCharCode(0x1F600 + _pairValues[i]) : '?',
                style: TextStyle(fontSize: visible ? 24 : 28, fontWeight: FontWeight.w900)),
            );
          },
        ));
      case GameType.dotsAndBoxes:
        return LayoutBuilder(builder: (context, constraints) {
          final side = math.min(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _tapDotEdge(d.localPosition, side),
            child: SizedBox(width: side, height: side,
              child: CustomPaint(painter: _DotsPainter(edges: _edges, boxes: _boxes)),
            ),
          );
        });
      default:
        return const Text('اللعبة غير مدعومة');
    }
  }

  Widget _cell({required Widget child, required VoidCallback onTap}) => Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: _finished ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Center(child: child),
        ),
      );

  Color themeColor(BuildContext context) => Theme.of(context).colorScheme.primary;

  void _swap(List<int> list, int a, int b) {
    final value = list[a];
    list[a] = list[b];
    list[b] = value;
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter({required this.edges, required this.boxes});
  final List<int> edges;
  final List<int> boxes;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 20.0;
    final step = (math.min(size.width, size.height) - pad * 2) / 3;
    final line = Paint()..strokeWidth = 5..strokeCap = StrokeCap.round;
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        final owner = boxes[r * 3 + c];
        if (owner != 0) {
          canvas.drawRect(Rect.fromLTWH(pad + c * step + 4, pad + r * step + 4, step - 8, step - 8),
              Paint()..color = owner == 1 ? const Color(0x3328B6A5) : const Color(0x33FF5D73));
        }
      }
    }
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 3; c++) {
        final owner = edges[r * 3 + c];
        if (owner == 0) continue;
        line.color = owner == 1 ? const Color(0xFF0D8274) : const Color(0xFFFF5D73);
        canvas.drawLine(Offset(pad + c * step, pad + r * step), Offset(pad + (c + 1) * step, pad + r * step), line);
      }
    }
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 4; c++) {
        final owner = edges[12 + r * 4 + c];
        if (owner == 0) continue;
        line.color = owner == 1 ? const Color(0xFF0D8274) : const Color(0xFFFF5D73);
        canvas.drawLine(Offset(pad + c * step, pad + r * step), Offset(pad + c * step, pad + (r + 1) * step), line);
      }
    }
    final dot = Paint()..color = const Color(0xFF263238);
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        canvas.drawCircle(Offset(pad + c * step, pad + r * step), 6, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter oldDelegate) => true;
}
