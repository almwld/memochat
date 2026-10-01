import 'package:flutter/material.dart';

class ChatBackground extends StatelessWidget {
  const ChatBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: dark ? const Color(0xFF0B1117) : const Color(0xFFF4F7F6),
          child: CustomPaint(
            painter: _ChatBackgroundPainter(dark: dark),
          ),
        ),
        child,
      ],
    );
  }
}

class _ChatBackgroundPainter extends CustomPainter {
  const _ChatBackgroundPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()
      ..style = PaintingStyle.fill
      ..color = dark ? const Color(0x14FFFFFF) : const Color(0x183D5B56);

    const spacing = 44.0;
    for (var y = 18.0; y < size.height + spacing; y += spacing) {
      for (var x = 18.0; x < size.width + spacing; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.1, dot);
      }
    }

    final accent = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = dark ? const Color(0x0C2BB195) : const Color(0x10218A7C);

    final radius = size.width * .42;
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width * .08, size.height * .16),
        radius: radius,
      ),
      .15,
      1.1,
      false,
      accent,
    );
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width * .92, size.height * .78),
        radius: radius * .9,
      ),
      3.25,
      1.05,
      false,
      accent,
    );

    final corner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = dark ? const Color(0x09FFFFFF) : const Color(0x0D3D5B56);

    for (var y = 0.0; y < size.height; y += 132) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), corner);
    }
  }

  @override
  bool shouldRepaint(covariant _ChatBackgroundPainter oldDelegate) =>
      oldDelegate.dark != dark;
}
