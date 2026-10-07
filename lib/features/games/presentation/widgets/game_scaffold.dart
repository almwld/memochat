import 'dart:async';

import 'package:flutter/material.dart';

class GameScaffold extends StatefulWidget {
  final String title;
  final int score;
  final Duration? duration;
  final Widget child;
  final Widget? quickChat;
  final VoidCallback? onClose;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final bool paused;
  final int? progress;
  final int? progressTotal;

  const GameScaffold({
    super.key,
    required this.title,
    required this.score,
    required this.child,
    this.duration,
    this.quickChat,
    this.onClose,
    this.onPause,
    this.onResume,
    this.paused = false,
    this.progress,
    this.progressTotal,
  });

  @override
  State<GameScaffold> createState() => _GameScaffoldState();
}

class _GameScaffoldState extends State<GameScaffold> {
  Timer? _timer;
  Duration? _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.duration;
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant GameScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _remaining = widget.duration;
      _startTimer();
    } else if (oldWidget.paused != widget.paused) {
      widget.paused ? _timer?.cancel() : _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.paused || _remaining == null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final value = _remaining;
      if (!mounted || value == null) return;
      if (value <= Duration.zero) {
        _timer?.cancel();
        setState(() => _remaining = Duration.zero);
        return;
      }
      setState(() => _remaining = value - const Duration(seconds: 1));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(Duration value) {
    final minutes = value.inMinutes.toString().padLeft(2, '0');
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasProgress = widget.progress != null &&
        widget.progressTotal != null &&
        widget.progressTotal! > 0;
    final progress = hasProgress
        ? (widget.progress! / widget.progressTotal!).clamp(0.0, 1.0).toDouble()
        : null;

    return Scaffold(
      appBar: AppBar(
        leading: widget.onClose == null
            ? null
            : IconButton(
                tooltip: 'إغلاق',
                icon: const Icon(Icons.close_rounded),
                onPressed: widget.onClose,
              ),
        title: Text(widget.title),
        centerTitle: true,
        actions: [
          if (widget.onPause != null && !widget.paused)
            IconButton(
              tooltip: 'إيقاف مؤقت',
              icon: const Icon(Icons.pause_rounded),
              onPressed: widget.onPause,
            ),
          if (widget.onResume != null && widget.paused)
            IconButton(
              tooltip: 'متابعة',
              icon: const Icon(Icons.play_arrow_rounded),
              onPressed: widget.onResume,
            ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'النقاط: ${widget.score}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (_remaining != null)
                        Text(
                          _format(_remaining!),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _remaining! <= const Duration(seconds: 10)
                                ? scheme.error
                                : scheme.onSurface,
                          ),
                        ),
                    ],
                  ),
                ),
                if (progress != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: LinearProgressIndicator(value: progress),
                  ),
                Expanded(child: widget.child),
              ],
            ),
            if (widget.quickChat != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 10,
                child: SafeArea(child: widget.quickChat!),
              ),
            if (widget.paused)
              const _PauseOverlay(),
          ],
        ),
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.pause_circle_outline_rounded, size: 48),
                SizedBox(height: 12),
                Text(
                  'اللعبة متوقفة مؤقتاً',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
