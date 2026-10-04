import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/game_leaderboard_service.dart';
import '../../services/game_achievement_service.dart';

class ClassicGameConfig {
  final String title;
  final String instruction;
  final List<String> options;
  final int correctIndex;
  const ClassicGameConfig({required this.title, required this.instruction, required this.options, required this.correctIndex});
}

class ClassicGameEngine extends StatefulWidget {
  final ClassicGameConfig config;
  const ClassicGameEngine({super.key, required this.config});
  @override State<ClassicGameEngine> createState() => _ClassicGameEngineState();
}

class _ClassicGameEngineState extends State<ClassicGameEngine> {
  final _random = Random();
  Timer? _timer;
  int _seconds = 30, _score = 0, _streak = 0, _round = 1; String? _selected; bool? _correct; bool _answered = false;
  int _score = 0;
  int _round = 1;
  bool _started = false;
  bool _paused = false;
  bool _finished = false;
  late List<String> _options;

  @override
  void initState() { super.initState(); _shuffle(); }

  void _shuffle() { _options = List<String>.from(widget.config.options)..shuffle(_random); }

  void _start() {
    setState(() => _started = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _paused) return;
      if (_seconds <= 1) {
        _finish();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  Future<void> _finish() async {
    _timer?.cancel();
    try {
      await GameLeaderboardService.instance.submitScore(gameId: widget.config.title, score: _score);
      if (_score >= 10) {
        await GameAchievementService.instance.unlock('score_10_${widget.config.title}');
      }
    } catch (_) {}
    if (mounted) setState(() => _finished = true);
  }

  void _answer(String value) {
    if (!_started || _paused || _finished) return;
    final correct = value == widget.config.options[widget.config.correctIndex];
    setState(() {
      if (correct) _score += 2;
      _round++;
      _seconds = max(0, _seconds - 1);
    });
    if (_seconds == 0) {
      _finish();
    } else {
      _shuffle();
    }
  }

  void _replay() {
    _timer?.cancel();
    setState(() {
      _seconds = 30;
      _score = 0;
      _round = 1;
      _started = false;
      _paused = false;
      _finished = false;
      _shuffle();
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (!_started) return _startView(context);
    if (_finished) return _resultView(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.config.title),
        actions: [
          IconButton(
            onPressed: () => setState(() => _paused = !_paused),
            icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('النقاط: $_score', style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('الجولة $_round'),
                    Text('$_seconds ث', style: TextStyle(fontWeight: FontWeight.w800, color: _seconds <= 10 ? Theme.of(context).colorScheme.error : null)),
                  ],
                ),
                const SizedBox(height: 24),
                Text(widget.config.instruction, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 24),
                ..._options.map((o) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SizedBox(width: double.infinity, child: FilledButton(onPressed: () => _answer(o), child: Text(o))),
                )),
              ],
            ),
          ),
          if (_paused)
            ColoredBox(
              color: Colors.black54,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.pause_circle, size: 52),
                        const SizedBox(height: 10),
                        const Text('متوقف مؤقتاً', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        FilledButton(onPressed: () => setState(() => _paused = false), child: const Text('متابعة')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _startView(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.config.title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sports_esports_rounded, size: 64),
              const SizedBox(height: 16),
              Text(widget.config.instruction, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _start,
                  icon: const Icon(Icons.play_arrow),
                  label: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('بدء اللعبة')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultView(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.config.title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events_rounded, size: 64),
              const SizedBox(height: 12),
              const Text('النتيجة النهائية', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              Text('$_score نقطة', style: const TextStyle(fontSize: 30)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(onPressed: _replay, icon: const Icon(Icons.replay), label: const Text('إعادة اللعب')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
