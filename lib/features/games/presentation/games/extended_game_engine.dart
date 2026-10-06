import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../services/game_achievement_service.dart';
import '../../services/game_leaderboard_service.dart';

class ExtendedGameConfig {
  final String title;
  final String instruction;
  final List<String> options;
  final int correctIndex;

  const ExtendedGameConfig({
    required this.title,
    required this.instruction,
    required this.options,
    required this.correctIndex,
  });
}

class ExtendedGameEngine extends StatefulWidget {
  final ExtendedGameConfig config;

  const ExtendedGameEngine({
    super.key,
    required this.config,
  });

  @override
  State<ExtendedGameEngine> createState() => _ExtendedGameEngineState();
}

class _ExtendedGameEngineState extends State<ExtendedGameEngine>
    with SingleTickerProviderStateMixin {
  static const _roundDuration = 45;

  final _random = Random();
  Timer? _timer;
  late final AnimationController _pulseController;

  int _seconds = _roundDuration;
  int _score = 0;
  int _round = 1;
  int _streak = 0;
  int _bestStreak = 0;
  int _correctAnswers = 0;
  int _wrongAnswers = 0;

  bool _started = false;
  bool _paused = false;
  bool _finished = false;
  bool _answered = false;

  String? _selected;
  bool? _lastCorrect;
  late List<String> _options;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      lowerBound: .96,
      upperBound: 1.0,
    )..repeat(reverse: true);
    _shuffle();
  }

  IconData get _icon {
    final title = widget.config.title.toLowerCase();
    if (title.contains('color')) return Icons.palette_rounded;
    if (title.contains('memory') || title.contains('card') || title.contains('pair')) {
      return Icons.grid_view_rounded;
    }
    if (title.contains('math')) return Icons.calculate_rounded;
    if (title.contains('word') || title.contains('anagram') || title.contains('language')) {
      return Icons.text_fields_rounded;
    }
    if (title.contains('rocket')) return Icons.rocket_launch_rounded;
    if (title.contains('galaxy')) return Icons.auto_awesome_rounded;
    if (title.contains('target')) return Icons.adjust_rounded;
    if (title.contains('bubble')) return Icons.circle_rounded;
    if (title.contains('maze')) return Icons.route_rounded;
    if (title.contains('tower') || title.contains('balance')) {
      return Icons.account_balance_rounded;
    }
    if (title.contains('light')) return Icons.lightbulb_rounded;
    if (title.contains('code')) return Icons.password_rounded;
    if (title.contains('rhythm') || title.contains('song')) return Icons.music_note_rounded;
    if (title.contains('quiz') ||
        title.contains('trivia') ||
        title.contains('history') ||
        title.contains('science') ||
        title.contains('geography') ||
        title.contains('animal') ||
        title.contains('food')) {
      return Icons.quiz_rounded;
    }
    if (title.contains('dice')) return Icons.casino_rounded;
    if (title.contains('draw')) return Icons.brush_rounded;
    if (title.contains('reaction') || title.contains('quick') || title.contains('fast')) {
      return Icons.bolt_rounded;
    }
    return Icons.sports_esports_rounded;
  }

  Color get _accent => Theme.of(context).colorScheme.primary;

  void _shuffle() {
    _options = List<String>.of(widget.config.options)..shuffle(_random);
    _selected = null;
    _answered = false;
    _lastCorrect = null;
  }

  void _start() {
    if (_started || _finished) return;
    setState(() => _started = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _paused || _finished) return;
      if (_seconds <= 1) {
        _finish();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  Future<void> _finish() async {
    if (_finished) return;
    _timer?.cancel();

    try {
      await GameLeaderboardService.instance.submitScore(
        gameId: widget.config.title,
        score: _score,
      );
      if (_score >= 10) {
        await GameAchievementService.instance.unlock(
          'score_10_${widget.config.title}',
        );
      }
    } catch (_) {
      // Leaderboard/achievement persistence must never block the local result.
    }

    if (mounted) {
      setState(() => _finished = true);
    }
  }

  void _answer(String value) {
    if (!_started || _paused || _finished || _answered) return;

    final correctValue = widget.config.options[widget.config.correctIndex];
    final isCorrect = value == correctValue;

    setState(() {
      _selected = value;
      _answered = true;
      _lastCorrect = isCorrect;

      if (isCorrect) {
        _correctAnswers++;
        _streak++;
        _bestStreak = max(_bestStreak, _streak);
        _score += 2 + min(_streak - 1, 3);
      } else {
        _wrongAnswers++;
        _streak = 0;
        _seconds = max(0, _seconds - 2);
      }
    });

    Future<void>.delayed(const Duration(milliseconds: 420), () {
      if (!mounted || _finished) return;
      if (_seconds <= 0) {
        _finish();
        return;
      }
      setState(() {
        _round++;
        _shuffle();
      });
    });
  }

  void _togglePause() {
    if (!_started || _finished) return;
    setState(() => _paused = !_paused);
  }

  void _replay() {
    _timer?.cancel();
    setState(() {
      _seconds = _roundDuration;
      _score = 0;
      _round = 1;
      _streak = 0;
      _bestStreak = 0;
      _correctAnswers = 0;
      _wrongAnswers = 0;
      _started = false;
      _paused = false;
      _finished = false;
      _shuffle();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.config.title),
          centerTitle: true,
        ),
        body: _startView(),
      );
    }

    if (_finished) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.config.title)),
        body: _resultView(),
      );
    }

    final progress = _seconds / _roundDuration;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.config.title),
        actions: [
          IconButton(
            tooltip: _paused ? 'متابعة' : 'إيقاف مؤقت',
            onPressed: _togglePause,
            icon: Icon(
              _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _scoreHeader(),
              const SizedBox(height: 12),
              _streakBanner(),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 7,
                ),
              ),
              const SizedBox(height: 22),
              _gameBadge(),
              const SizedBox(height: 18),
              _instructionCard(),
              const SizedBox(height: 18),
              ...List.generate(
                _options.length,
                (index) => _answerCard(index, _options[index]),
              ),
            ],
          ),
          if (_paused) _pauseOverlay(),
        ],
      ),
    );
  }

  Widget _scoreHeader() {
    final warning = _seconds <= 10;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(.12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _stat(
              Icons.stars_rounded,
              'النقاط',
              '$_score',
            ),
          ),
          Expanded(
            child: _stat(
              Icons.check_circle_outline_rounded,
              'صحيح',
              '$_correctAnswers',
            ),
          ),
          Expanded(
            child: _stat(
              Icons.timer_outlined,
              'الوقت',
              '$_seconds ث',
              valueColor: warning
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Column(
      children: [
        Icon(icon, size: 19, color: _accent),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: valueColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _streakBanner() {
    final active = _streak > 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: active
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(.16),
        ),
      ),
      child: Row(
        children: [
          Icon(
            active ? Icons.local_fire_department_rounded : Icons.bolt_rounded,
            color: _accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              active
                  ? 'سلسلة $_streak — استمر للحصول على نقاط إضافية'
                  : 'أجب بسرعة وبشكل صحيح لبناء سلسلة',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            '$_round',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: _accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _gameBadge() {
    return ScaleTransition(
      scale: _pulseController,
      child: Center(
        child: Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.primaryContainer,
            boxShadow: [
              BoxShadow(
                color: _accent.withOpacity(.14),
                blurRadius: 26,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Icon(_icon, size: 52, color: _accent),
          ),
        ),
      ),
    );
  }

  Widget _instructionCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        widget.config.instruction,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 19,
          height: 1.35,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _answerCard(int index, String value) {
    final selected = _selected == value;
    final correct = value == widget.config.options[widget.config.correctIndex];
    final showState = selected && _lastCorrect != null;

    Color? borderColor;
    IconData trailing = Icons.chevron_left_rounded;

    if (showState) {
      borderColor = correct
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.error;
      trailing = correct
          ? Icons.check_circle_rounded
          : Icons.cancel_rounded;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: borderColor ??
                Theme.of(context).colorScheme.outline.withOpacity(.14),
            width: showState ? 2 : 1,
          ),
        ),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _answer(value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      value,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(trailing),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pauseOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(28),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pause_circle_filled_rounded, size: 58, color: _accent),
                  const SizedBox(height: 10),
                  const Text(
                    'متوقف مؤقتاً',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  const Text('يمكنك المتابعة من حيث توقفت.'),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => setState(() => _paused = false),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('متابعة'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _startView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _pulseController,
              child: Container(
                width: 118,
                height: 118,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                child: Icon(_icon, size: 58, color: _accent),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.config.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              widget.config.instruction,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 1.45,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _introChip(Icons.timer_outlined, '45 ثانية'),
                const SizedBox(width: 8),
                _introChip(Icons.bolt_rounded, 'سلسلة نقاط'),
                const SizedBox(width: 8),
                _introChip(Icons.leaderboard_rounded, 'متصدرون'),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 3),
                  child: Text('بدء اللعبة'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _introChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _accent),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _resultView() {
    final total = _correctAnswers + _wrongAnswers;
    final accuracy = total == 0 ? 0 : ((_correctAnswers / total) * 100).round();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(_icon, size: 68, color: _accent),
            const SizedBox(height: 14),
            const Text(
              'النتيجة النهائية',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              '$_score نقطة',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: _accent,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _resultStat('الإجابات الصحيحة', '$_correctAnswers')),
                const SizedBox(width: 10),
                Expanded(child: _resultStat('أفضل سلسلة', '$_bestStreak')),
                const SizedBox(width: 10),
                Expanded(child: _resultStat('الدقة', '$accuracy%')),
              ],
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _replay,
                icon: const Icon(Icons.replay_rounded),
                label: const Text('إعادة اللعب'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _accent,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
