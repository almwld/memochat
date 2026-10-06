import 'dart:math' as math;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class BubblePopArcadeGame extends FlameGame {
  BubblePopArcadeGame({required this.onScore, this.durationSeconds = 30});
  final ValueChanged<int> onScore;
  final int durationSeconds;
  final math.Random _random = math.Random();
  final List<_Bubble> _bubbles = <_Bubble>[];
  double _elapsed = 0;
  int _score = 0;
  double _spawnClock = 0;

  @override
  Color backgroundColor() => const Color(0xFF071719);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (_bubbles.isEmpty && size.x > 0 && size.y > 0) {
      for (var i = 0; i < 7; i++) _spawn(initial: true);
    }
  }

  void _spawn({bool initial = false}) {
    if (_bubbles.length >= 10 || size.x <= 0 || size.y <= 0) return;
    final radius = 20 + _random.nextDouble() * 27;
    final margin = radius + 8;
    _bubbles.add(_Bubble(
      position: Vector2(
        margin + _random.nextDouble() * math.max(1, size.x - margin * 2),
        90 + _random.nextDouble() * math.max(1, size.y - 125),
      ),
      radius: radius,
      velocity: Vector2(
        (_random.nextDouble() - .5) * (initial ? 30 : 75),
        (_random.nextDouble() - .5) * (initial ? 30 : 75),
      ),
      phase: _random.nextDouble() * math.pi * 2,
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= durationSeconds) {
      pauseEngine();
      return;
    }
    _spawnClock += dt;
    if (_spawnClock > .65) {
      _spawnClock = 0;
      _spawn();
    }
    for (final bubble in _bubbles) {
      bubble.age += dt;
      bubble.position += bubble.velocity * dt;
      final r = bubble.radius;
      if (bubble.position.x < r || bubble.position.x > size.x - r) {
        bubble.velocity.x *= -1;
        bubble.position.x = bubble.position.x.clamp(r, size.x - r).toDouble();
      }
      if (bubble.position.y < 75 + r || bubble.position.y > size.y - r) {
        bubble.velocity.y *= -1;
        bubble.position.y = bubble.position.y.clamp(75 + r, size.y - r).toDouble();
      }
    }
    _bubbles.removeWhere((b) => b.age > 7);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final paint = Paint()..style = PaintingStyle.fill;
    for (final bubble in _bubbles) {
      final pulse = 1 + math.sin(bubble.age * 4 + bubble.phase) * .06;
      final r = bubble.radius * pulse;
      paint.color = _palette[bubble.colorIndex];
      canvas.drawCircle(Offset(bubble.position.x, bubble.position.y), r, paint);
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withOpacity(.38);
      canvas.drawCircle(Offset(bubble.position.x, bubble.position.y), r, paint);
      paint
        ..style = PaintingStyle.fill
        ..color = Colors.white.withOpacity(.20);
      canvas.drawCircle(
        Offset(bubble.position.x - r * .28, bubble.position.y - r * .28),
        r * .20,
        paint,
      );
    }

    final hud = TextPainter(
      text: TextSpan(
        text: _score.toString() + '    ' +
            math.max(0, durationSeconds - _elapsed.floor()).toString() + ' ث',
        style: const TextStyle(
          color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    hud.paint(canvas, Offset(size.x / 2 - hud.width / 2, 24));

    final label = TextPainter(
      text: const TextSpan(
        text: 'اضغط الفقاعات قبل أن تختفي',
        style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 12),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    label.paint(canvas, Offset(size.x / 2 - label.width / 2, 54));
  }

  void tap(Vector2 point) {
    for (var i = _bubbles.length - 1; i >= 0; i--) {
      final bubble = _bubbles[i];
      if (point.distanceTo(bubble.position) <= bubble.radius * 1.12) {
        _bubbles.removeAt(i);
        _score++;
        onScore(_score);
        return;
      }
    }
  }

  static const _palette = <Color>[
    Color(0xFF18B6A4), Color(0xFF43C7E8), Color(0xFF7C83FF),
    Color(0xFFFFB454), Color(0xFFFF6B8A),
  ];
}

class _Bubble {
  _Bubble({
    required this.position, required this.radius,
    required this.velocity, required this.phase,
  }) : colorIndex = math.Random().nextInt(5);

  final Vector2 position;
  final double radius;
  final Vector2 velocity;
  final double phase;
  final int colorIndex;
  double age = 0;
}
