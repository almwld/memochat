import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/game_catalog.dart';
import '../data/game_service.dart';

class GamePlayScreen extends StatefulWidget {
  const GamePlayScreen({required this.game, super.key});
  final GameDefinition game;
  @override State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen> {
  final _random = Random();
  final _service = GameService();
  Timer? _timer;
  int _seconds = 45;
  int _score = 0;
  int _level = 1;
  int _combo = 0;
  int _best = 0;
  bool _paused = false;
  bool _finished = false;
  int _target = 0;
  int _mathAnswer = 0;
  List<int> _mathOptions = const [];
  List<int> _cards = const [];
  final _revealed = <int>{};
  final _matched = <int>{};
  int? _firstCard;
  bool _checking = false;

  bool get _memoryMode => widget.game.id == 'memory_match' || widget.game.id == 'card_flip' || widget.game.id == 'emoji_memory';
  bool get _mathMode => widget.game.id == 'math' || widget.game.id == 'math_duel' || widget.game.id == 'number_puzzle';

  @override
  void initState() {
    super.initState();
    _bestScore();
    _startRound();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _paused || _finished) return;
      if (_seconds <= 1) { _finish(); } else { setState(() => _seconds--); }
    });
  }

  Future<void> _bestScore() async {
    final best = await _service.bestScore(widget.game.id);
    if (mounted) setState(() => _best = best);
  }

  void _startRound() {
    if (_memoryMode) {
      final values = List<int>.generate(8, (i) => i)..addAll(List<int>.generate(8, (i) => i));
      values.shuffle(_random);
      _cards = values;
    } else if (_mathMode) {
      _newMath();
    } else {
      _target = _random.nextInt(9);
    }
  }

  void _newMath() {
    final a = 2 + _random.nextInt(8 + _level * 2);
    final b = 1 + _random.nextInt(8 + _level * 2);
    _mathAnswer = a + b;
    final options = <int>{_mathAnswer};
    while (options.length < 4) options.add(max(0, _mathAnswer + _random.nextInt(9) - 4));
    _mathOptions = options.toList()..shuffle(_random);
    _target = 0;
  }

  void _scorePoint({int points = 10}) {
    _combo++;
    final earned = points + (_combo ~/ 3) * 2;
    setState(() { _score += earned; _level = 1 + (_score ~/ 100); });
    HapticFeedback.selectionClick();
  }

  void _answer(int index) {
    if (_paused || _finished) return;
    if (_mathMode) {
      if (_mathOptions[index] == _mathAnswer) { _scorePoint(points: 12); } else { setState(() => _combo = 0); HapticFeedback.vibrate(); }
      _newMath();
      setState(() {});
      return;
    }
    if (_target == index) { _scorePoint(); _target = _random.nextInt(9); setState(() {}); } else { setState(() => _combo = 0); HapticFeedback.vibrate(); }
  }

  Future<void> _tapCard(int index) async {
    if (_checking || _paused || _finished || _matched.contains(index)) return;
    if (_revealed.contains(index)) return;
    setState(() => _revealed.add(index));
    if (_firstCard == null) { _firstCard = index; return; }
    final first = _firstCard!;
    _firstCard = null;
    _checking = true;
    if (_cards[first] == _cards[index]) {
      _matched.addAll([first, index]);
      _scorePoint(points: 18);
      if (_matched.length == _cards.length) {
        _level++;
        _startRound();
        _revealed.clear();
        _matched.clear();
      }
    } else {
      setState(() {});
      await Future<void>.delayed(const Duration(milliseconds: 420));
      if (mounted) _revealed.removeAll([first, index]);
      setState(() => _combo = 0);
    }
    _checking = false;
    if (mounted) setState(() {});
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    await _service.saveScore(gameId: widget.game.id, score: _score, level: _level);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('انتهت الجولة', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.emoji_events_rounded, size: 54, color: widget.game.color),
          const SizedBox(height: 10),
          Text('نتيجتك $_score نقطة', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(_score > _best ? 'رقم قياسي جديد!' : 'أفضل نتيجة: $_best'),
        ]),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: const Text('إنهاء')),
          FilledButton(onPressed: () { Navigator.pop(context); _restart(); }, child: const Text('جولة جديدة')),
        ],
      ),
    );
  }

  void _restart() {
    _timer?.cancel();
    setState(() { _seconds = 45; _score = 0; _level = 1; _combo = 0; _finished = false; _paused = false; _revealed.clear(); _matched.clear(); _firstCard = null; _startRound(); });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) { if (!mounted || _paused || _finished) return; if (_seconds <= 1) _finish(); else setState(() => _seconds--); });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(widget.game.title, style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [IconButton(onPressed: () => setState(() => _paused = !_paused), icon: Icon(_paused ? Icons.play_arrow_rounded : Icons.pause_rounded))],
      ),
      body: Stack(children: [
        CustomPaint(painter: _GameBackdropPainter(widget.game.color), size: Size.infinite),
        SafeArea(child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 12), child: Row(children: [
            _Stat(label: 'النقاط', value: '$_score', color: widget.game.color),
            const SizedBox(width: 8), _Stat(label: 'المستوى', value: '$_level', color: scheme.secondary),
            const SizedBox(width: 8), _Stat(label: 'الوقت', value: '$_seconds', color: scheme.error),
            if (_combo > 1) ...[const SizedBox(width: 8), _Stat(label: 'سلسلة', value: 'x$_combo', color: Colors.orange)],
          ])),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: LinearProgressIndicator(value: _seconds / 45, minHeight: 6, borderRadius: BorderRadius.circular(8), color: widget.game.color)),
          const SizedBox(height: 20),
          Expanded(child: _memoryMode ? _buildMemory() : _buildChallenge()),
          Padding(padding: const EdgeInsets.all(16), child: Text(widget.game.subtitle, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600))),
        ])),
        if (_paused) Positioned.fill(child: ColoredBox(color: Colors.black54, child: Center(child: Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.pause_circle_outline_rounded, size: 52), const SizedBox(height: 12), const Text('اللعبة متوقفة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), const SizedBox(height: 14), FilledButton(onPressed: () => setState(() => _paused = false), child: const Text('متابعة'))]))))),
      ]),
    );
  }

  Widget _buildChallenge() => Padding(padding: const EdgeInsets.all(20), child: Column(children: [
    const SizedBox(height: 18),
    Text(_mathMode ? 'اختر الإجابة الصحيحة' : 'اضغط الهدف المضيء', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
    const SizedBox(height: 24),
    if (_mathMode) Text('$_mathAnswer = ؟', style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900)),
    if (!_mathMode) _TargetOrb(color: widget.game.color),
    const SizedBox(height: 28),
    Expanded(child: GridView.builder(itemCount: 9, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12), itemBuilder: (_, index) {
      if (_mathMode && index >= 4) return const SizedBox.shrink();
      final active = !_mathMode && _target == index;
      return InkWell(onTap: () => _mathMode ? _answer(index) : _answer(index), borderRadius: BorderRadius.circular(22), child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), gradient: LinearGradient(colors: [widget.game.color.withOpacity(active ? .95 : .12), widget.game.color.withOpacity(active ? .55 : .05)]), boxShadow: active ? [BoxShadow(color: widget.game.color.withOpacity(.35), blurRadius: 18)] : null), child: Center(child: _mathMode ? Text('${_mathOptions[index]}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)) : Icon(active ? Icons.bolt_rounded : Icons.circle_outlined, color: active ? Colors.white : widget.game.color.withOpacity(.25), size: active ? 34 : 22))));
    })),
  ]));

  Widget _buildMemory() => Padding(padding: const EdgeInsets.all(20), child: Column(children: [
    const Text('طابق البطاقات المتشابهة', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
    const SizedBox(height: 18),
    Expanded(child: GridView.builder(itemCount: _cards.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 9, mainAxisSpacing: 9), itemBuilder: (_, index) {
      final open = _revealed.contains(index) || _matched.contains(index);
      return InkWell(onTap: () => _tapCard(index), borderRadius: BorderRadius.circular(16), child: AnimatedContainer(duration: const Duration(milliseconds: 180), decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: LinearGradient(colors: open ? [widget.game.color.withOpacity(.95), widget.game.color.withOpacity(.55)] : [schemeColor(context).surfaceContainerHighest, schemeColor(context).surfaceContainer], begin: Alignment.topLeft, end: Alignment.bottomRight), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 7, offset: Offset(0, 4))]), child: Center(child: open ? Text('${_cards[index] + 1}', style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)) : Icon(Icons.lock_outline_rounded, color: widget.game.color.withOpacity(.45)))));
    })),
  ]));

  ColorScheme schemeColor(BuildContext context) => Theme.of(context).colorScheme;
}

class _Stat extends StatelessWidget { const _Stat({required this.label, required this.value, required this.color}); final String label; final String value; final Color color; @override Widget build(BuildContext context) => Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 9), decoration: BoxDecoration(color: color.withOpacity(.11), borderRadius: BorderRadius.circular(14)), child: Column(children: [Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16)), Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10))]))); }
class _TargetOrb extends StatelessWidget { const _TargetOrb({required this.color}); final Color color; @override Widget build(BuildContext context) => Container(width: 104, height: 104, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Colors.white, color, Color.lerp(color, Colors.black, .35)!], center: const Alignment(-.35, -.35)), boxShadow: [BoxShadow(color: color.withOpacity(.45), blurRadius: 25, spreadRadius: 4)]), child: const Icon(Icons.stars_rounded, color: Colors.white, size: 42)); }
class _GameBackdropPainter extends CustomPainter { const _GameBackdropPainter(this.color); final Color color; @override void paint(Canvas canvas, Size size) { final p = Paint()..color = color.withOpacity(.035); for (var i = 0; i < 8; i++) { canvas.drawCircle(Offset(size.width * ((i * 37) % 100) / 100, 90 + i * 130), 70 + i * 9, p); } } @override bool shouldRepaint(covariant _GameBackdropPainter oldDelegate) => oldDelegate.color != color; }
