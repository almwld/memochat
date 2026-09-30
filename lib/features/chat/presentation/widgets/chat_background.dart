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
        ColoredBox(
          color: isDark ? const Color(0xFF0B141A) : const Color(0xFFECE5DD),
          child: CustomPaint(
            painter: _ChatBackgroundPainter(isDark: isDark),
          ),
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
    final base = Paint()..style = PaintingStyle.fill;
    base.color = isDark ? const Color(0xFF0B141A) : const Color(0xFFECE5DD);
    canvas.drawRect(Offset.zero & size, base);

    // Dense, low-contrast doodle field inspired by familiar chat wallpaper
    // patterns. The artwork is original rather than copying a proprietary
    // wallpaper asset.
    final iconColor =
        isDark ? const Color(0x14D7E9E4) : const Color(0x18556B63);
    final accentColor =
        isDark ? const Color(0x0C7AD1C5) : const Color(0x0D6A9B90);

    final pattern = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = iconColor;

    final accent = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = accentColor;

    final stepX = math.max(72.0, size.width / 4.15);
    const stepY = 76.0;

    for (var row = -1; row < size.height / stepY + 2; row++) {
      for (var col = -1; col < size.width / stepX + 2; col++) {
        final seed = (row * 37 + col * 71).abs();
        final x = col * stepX + (row.isOdd ? stepX * .48 : 0);
        final y = row * stepY;
        final type = seed % 12;

        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(((seed % 9) - 4) * .035);

        switch (type) {
          case 0:
            _drawBubble(canvas, pattern, 18);
            break;
          case 1:
            _drawPhone(canvas, pattern, 18);
            break;
          case 2:
            _drawCamera(canvas, pattern, 17);
            break;
          case 3:
            _drawHeart(canvas, pattern, 15);
            break;
          case 4:
            _drawSmile(canvas, pattern, 17);
            break;
          case 5:
            _drawStar(canvas, pattern, 15);
            break;
          case 6:
            _drawLock(canvas, pattern, 16);
            break;
          case 7:
            _drawMic(canvas, pattern, 16);
            break;
          case 8:
            _drawLink(canvas, pattern, 16);
            break;
          case 9:
            _drawPaperclip(canvas, pattern, 17);
            break;
          case 10:
            _drawCheck(canvas, accent, 18);
            break;
          default:
            _drawDots(canvas, pattern, 16);
        }

        canvas.restore();
      }
    }

    // Extra micro-doodles keep the surface visually rich without becoming
    // distracting behind message bubbles.
    final micro = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8
      ..color = isDark ? const Color(0x0BFFFFFF) : const Color(0x0C263238);

    for (var y = -20.0; y < size.height + 30; y += 38) {
      for (var x = ((y ~/ 38).isOdd ? -10.0 : 8.0);
          x < size.width + 30;
          x += 54) {
        final r = 2.0 + (((x.toInt() + y.toInt()) ~/ 7).abs() % 3);
        canvas.drawCircle(Offset(x, y), r, micro);
      }
    }
  }

  void _drawBubble(Canvas c, Paint p, double s) {
    final path = Path()
      ..moveTo(-s, -s * .62)
      ..quadraticBezierTo(0, -s, s, -s * .62)
      ..quadraticBezierTo(s * 1.08, 0, s * .62, s * .55)
      ..lineTo(s * .45, s)
      ..lineTo(s * .05, s * .55)
      ..quadraticBezierTo(-s, s * .7, -s, -s * .62);
    c.drawPath(path, p);
    c.drawLine(Offset(-s * .45, -2), Offset(s * .4, -2), p);
    c.drawLine(Offset(-s * .45, s * .28), Offset(s * .15, s * .28), p);
  }

  void _drawPhone(Canvas c, Paint p, double s) {
    final path = Path()
      ..moveTo(-s * .55, -s * .7)
      ..quadraticBezierTo(-s * .8, -s * .2, -s * .35, s * .45)
      ..quadraticBezierTo(0, s * .85, s * .55, s * .45)
      ..lineTo(s * .2, s * .1)
      ..lineTo(-s * .05, s * .3)
      ..quadraticBezierTo(-s * .35, 0, -s * .05, -s * .3)
      ..lineTo(s * .2, -s * .05);
    c.drawPath(path, p);
  }

  void _drawCamera(Canvas c, Paint p, double s) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: s * 1.9, height: s * 1.2),
        const Radius.circular(5),
      ),
      p,
    );
    final lens = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = p.color;
    c.drawCircle(Offset.zero, s * .3, lens);
    c.drawLine(Offset(-s * .65, -s * .62), Offset(-s * .2, -s * .62), p);
  }

  void _drawHeart(Canvas c, Paint p, double s) {
    final path = Path()
      ..moveTo(0, s * .9)
      ..cubicTo(-s * .25, s * .55, -s, s * .1, -s * .82, -s * .4)
      ..cubicTo(-s * .65, -s, -.1 * s, -s * .9, 0, -s * .35)
      ..cubicTo(.1 * s, -s * .9, s * .65, -s, s * .82, -s * .4)
      ..cubicTo(s, s * .1, s * .25, s * .55, 0, s * .9);
    c.drawPath(path, p);
  }

  void _drawSmile(Canvas c, Paint p, double s) {
    c.drawCircle(Offset.zero, s * .78, p);
    c.drawCircle(Offset(-s * .27, -s * .2), s * .08, p);
    c.drawCircle(Offset(s * .27, -s * .2), s * .08, p);
    c.drawArc(
      Rect.fromCenter(center: Offset(0, s * .05), width: s * .8, height: s * .55),
      .15,
      math.pi - .3,
      false,
      p,
    );
  }

  void _drawStar(Canvas c, Paint p, double s) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final r = i.isEven ? s : s * .42;
      final point = Offset(math.cos(a) * r, math.sin(a) * r);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    c.drawPath(path, p);
  }

  void _drawLock(Canvas c, Paint p, double s) {
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

  void _drawMic(Canvas c, Paint p, double s) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, -s * .05), width: s * .55, height: s * 1.15),
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

  void _drawLink(Canvas c, Paint p, double s) {
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

  void _drawPaperclip(Canvas c, Paint p, double s) {
    final path = Path()
      ..moveTo(s * .35, -s * .7)
      ..cubicTo(s, -s * .25, s * .25, s * .8, -s * .3, s * .65)
      ..cubicTo(-s * .8, s * .5, -s * .65, -s * .5, -.05 * s, -s * .45)
      ..cubicTo(s * .45, -s * .4, s * .35, s * .35, 0, s * .25);
    c.drawPath(path, p);
  }

  void _drawCheck(Canvas c, Paint p, double s) {
    c.drawLine(Offset(-s * .65, 0), Offset(-s * .12, s * .48), p);
    c.drawLine(Offset(-s * .12, s * .48), Offset(s * .72, -s * .52), p);
  }

  void _drawDots(Canvas c, Paint p, double s) {
    for (var i = 0; i < 3; i++) {
      c.drawCircle(Offset((i - 1) * s * .45, 0), s * .1, p);
    }
  }

  @override
  bool shouldRepaint(covariant _ChatBackgroundPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
