import 'dart:math' as math;

import 'package:flutter/material.dart';

class ChatBackground extends StatelessWidget {
  final Widget child;

  const ChatBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: _ChatBackgroundPainter(isDark: isDark),
        ),
        child,
      ],
    );
  }
}

class _ChatBackgroundPainter extends CustomPainter {
  const _ChatBackgroundPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [Color(0xFF071116), Color(0xFF0B171D), Color(0xFF081217)]
            : const [Color(0xFFF3EEE8), Color(0xFFECE5DD), Color(0xFFE7E1DA)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    // Very subtle atmospheric depth: broad, blurred-free tonal pools keep
    // the wallpaper dimensional while remaining inexpensive to render.
    final glow = Paint()..style = PaintingStyle.fill;
    glow.color = isDark ? const Color(0x0619A894) : const Color(0x071C8A78);
    canvas.drawCircle(
      Offset(size.width * .12, size.height * .18),
      size.width * .55,
      glow,
    );
    glow.color = isDark ? const Color(0x052A6F80) : const Color(0x05B47B62);
    canvas.drawCircle(
      Offset(size.width * .9, size.height * .72),
      size.width * .6,
      glow,
    );

    final primary = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = isDark ? const Color(0x18D9E7E4) : const Color(0x20566C64);

    final secondary = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .9
      ..strokeCap = StrokeCap.round
      ..color = isDark ? const Color(0x0D79D4C5) : const Color(0x126C938A);

    final fine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7
      ..color = isDark ? const Color(0x09FFFFFF) : const Color(0x0D263238);

    // Two-scale pattern: a large recognizable doodle layer and a fine
    // micro-pattern. This creates the dense visual language of modern
    // messaging wallpapers without competing with message bubbles.
    final largeX = math.max(82.0, size.width / 3.35);
    const largeY = 92.0;
    for (var row = -1; row < size.height / largeY + 2; row++) {
      for (var col = -1; col < size.width / largeX + 2; col++) {
        final seed = (row * 97 + col * 53).abs();
        final x = col * largeX + (row.isOdd ? largeX * .43 : 0);
        final y = row * largeY;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(((seed % 13) - 6) * .045);
        _drawLargeIcon(canvas, seed % 14, primary, secondary);
        canvas.restore();
      }
    }

    const microX = 48.0;
    const microY = 44.0;
    for (var row = -1; row < size.height / microY + 2; row++) {
      for (var col = -1; col < size.width / microX + 2; col++) {
        final seed = (row * 31 + col * 67).abs();
        final x = col * microX + (row.isOdd ? 17 : 0);
        final y = row * microY;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(((seed % 7) - 3) * .08);
        _drawMicro(canvas, seed % 7, fine);
        canvas.restore();
      }
    }
  }

  void _drawLargeIcon(Canvas c, int type, Paint p, Paint accent) {
    switch (type) {
      case 0:
        _bubble(c, p, 17);
        break;
      case 1:
        _phone(c, p, 18);
        break;
      case 2:
        _camera(c, p, 17);
        break;
      case 3:
        _heart(c, p, 16);
        break;
      case 4:
        _smile(c, p, 17);
        break;
      case 5:
        _star(c, accent, 16);
        break;
      case 6:
        _lock(c, p, 16);
        break;
      case 7:
        _mic(c, p, 16);
        break;
      case 8:
        _link(c, p, 16);
        break;
      case 9:
        _paperclip(c, p, 17);
        break;
      case 10:
        _check(c, accent, 18);
        break;
      case 11:
        _cloud(c, p, 18);
        break;
      case 12:
        _music(c, p, 16);
        break;
      default:
        _spark(c, accent, 17);
    }
  }

  void _drawMicro(Canvas c, int type, Paint p) {
    switch (type) {
      case 0:
        for (var i = 0; i < 3; i++) {
          c.drawCircle(Offset((i - 1) * 4.5, 0), 1.2, p);
        }
        break;
      case 1:
        c.drawCircle(Offset.zero, 3.4, p);
        c.drawCircle(Offset.zero, 1.1, p);
        break;
      case 2:
        c.drawLine(const Offset(-5, 0), const Offset(5, 0), p);
        c.drawLine(const Offset(0, -5), const Offset(0, 5), p);
        break;
      case 3:
        _check(c, p, 6);
        break;
      case 4:
        _spark(c, p, 7);
        break;
      case 5:
        c.drawArc(
          const Rect.fromLTWH(-5, -3, 10, 6),
          0,
          math.pi,
          false,
          p,
        );
        break;
      default:
        c.drawCircle(Offset.zero, 2.2, p);
    }
  }

  void _bubble(Canvas c, Paint p, double s) {
    final path = Path()
      ..moveTo(-s, -s * .55)
      ..quadraticBezierTo(0, -s, s, -s * .55)
      ..quadraticBezierTo(s * 1.05, 0, s * .55, s * .55)
      ..lineTo(s * .35, s)
      ..lineTo(0, s * .52)
      ..quadraticBezierTo(-s, s * .68, -s, -s * .55);
    c.drawPath(path, p);
    c.drawLine(Offset(-s * .45, -2), Offset(s * .38, -2), p);
    c.drawLine(Offset(-s * .45, s * .27), Offset(s * .08, s * .27), p);
  }

  void _phone(Canvas c, Paint p, double s) {
    final path = Path()
      ..moveTo(-s * .52, -s * .72)
      ..quadraticBezierTo(-s * .78, -.2 * s, -.34 * s, .46 * s)
      ..quadraticBezierTo(0, .84 * s, .55 * s, .44 * s)
      ..lineTo(.18 * s, .08 * s)
      ..lineTo(-.08 * s, .28 * s)
      ..quadraticBezierTo(-.32 * s, 0, -.02 * s, -.28 * s)
      ..lineTo(.22 * s, -.06 * s);
    c.drawPath(path, p);
  }

  void _camera(Canvas c, Paint p, double s) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: s * 1.9, height: s * 1.18),
        const Radius.circular(5),
      ),
      p,
    );
    c.drawCircle(Offset.zero, s * .3, p);
    c.drawLine(Offset(-s * .65, -s * .6), Offset(-s * .2, -s * .6), p);
  }

  void _heart(Canvas c, Paint p, double s) {
    final path = Path()
      ..moveTo(0, s * .9)
      ..cubicTo(-s * .2, s * .55, -s, s * .05, -s * .8, -s * .42)
      ..cubicTo(-s * .6, -s, -.12 * s, -.88 * s, 0, -.3 * s)
      ..cubicTo(.12 * s, -.88 * s, .6 * s, -s, .8 * s, -.42 * s)
      ..cubicTo(s, .05 * s, .2 * s, .55 * s, 0, .9 * s);
    c.drawPath(path, p);
  }

  void _smile(Canvas c, Paint p, double s) {
    c.drawCircle(Offset.zero, s * .76, p);
    c.drawCircle(Offset(-s * .26, -s * .2), s * .07, p);
    c.drawCircle(Offset(s * .26, -s * .2), s * .07, p);
    c.drawArc(
      Rect.fromCenter(center: Offset(0, s * .06), width: s * .78, height: s * .5),
      .15,
      math.pi - .3,
      false,
      p,
    );
  }

  void _star(Canvas c, Paint p, double s) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final angle = -math.pi / 2 + i * math.pi / 5;
      final radius = i.isEven ? s : s * .42;
      final point = Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    c.drawPath(path, p);
  }

  void _lock(Canvas c, Paint p, double s) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, s * .18),
          width: s * 1.15,
          height: s * .95,
        ),
        const Radius.circular(3),
      ),
      p,
    );
    c.drawArc(
      Rect.fromCenter(
        center: Offset(0, -s * .18),
        width: s * .85,
        height: s * .9,
      ),
      math.pi,
      math.pi,
      false,
      p,
    );
  }

  void _mic(Canvas c, Paint p, double s) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, -s * .05),
          width: s * .55,
          height: s * 1.15,
        ),
        const Radius.circular(10),
      ),
      p,
    );
    c.drawArc(
      Rect.fromCenter(center: Offset(0, s * .05), width: s * 1.1, height: s * 1.25),
      0,
      math.pi,
      false,
      p,
    );
    c.drawLine(Offset(0, s * .67), Offset(0, s * .95), p);
    c.drawLine(Offset(-s * .3, s * .95), Offset(s * .3, s * .95), p);
  }

  void _link(Canvas c, Paint p, double s) {
    c.drawArc(
      Rect.fromCenter(center: Offset(-s * .28, 0), width: s * .95, height: s * .55),
      math.pi * .1,
      math.pi * 1.25,
      false,
      p,
    );
    c.drawArc(
      Rect.fromCenter(center: Offset(s * .28, 0), width: s * .95, height: s * .55),
      math.pi * 1.1,
      math.pi * 1.25,
      false,
      p,
    );
  }

  void _paperclip(Canvas c, Paint p, double s) {
    final path = Path()
      ..moveTo(s * .35, -s * .7)
      ..cubicTo(s, -.25 * s, .25 * s, .8 * s, -.3 * s, .65 * s)
      ..cubicTo(-.8 * s, .5 * s, -.65 * s, -.5 * s, -.05 * s, -.45 * s)
      ..cubicTo(.45 * s, -.4 * s, .35 * s, .35 * s, 0, .25 * s);
    c.drawPath(path, p);
  }

  void _check(Canvas c, Paint p, double s) {
    c.drawLine(Offset(-s * .65, 0), Offset(-s * .12, s * .48), p);
    c.drawLine(Offset(-s * .12, s * .48), Offset(s * .72, -s * .52), p);
  }

  void _cloud(Canvas c, Paint p, double s) {
    final path = Path()
      ..moveTo(-s * .85, s * .25)
      ..quadraticBezierTo(-s, -.15 * s, -.55 * s, -.28 * s)
      ..quadraticBezierTo(-.4 * s, -.85 * s, .08 * s, -.72 * s)
      ..quadraticBezierTo(.4 * s, -s * .8, .55 * s, -.35 * s)
      ..quadraticBezierTo(s, -.25 * s, .88 * s, .28 * s)
      ..lineTo(-s * .85, s * .28);
    c.drawPath(path, p);
  }

  void _music(Canvas c, Paint p, double s) {
    c.drawLine(Offset(s * .35, -s * .7), Offset(s * .35, s * .38), p);
    c.drawLine(Offset(s * .35, -s * .7), Offset(s * .78, -s * .82), p);
    c.drawCircle(Offset(0, s * .48), s * .27, p);
  }

  void _spark(Canvas c, Paint p, double s) {
    c.drawLine(Offset(0, -s), Offset(0, s), p);
    c.drawLine(Offset(-s, 0), Offset(s, 0), p);
    c.drawLine(Offset(-s * .55, -s * .55), Offset(s * .55, s * .55), p);
    c.drawLine(Offset(s * .55, -s * .55), Offset(-s * .55, s * .55), p);
  }

  @override
  bool shouldRepaint(covariant _ChatBackgroundPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
