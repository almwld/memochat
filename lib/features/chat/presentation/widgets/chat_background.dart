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
          color: isDark ? const Color(0xFF0B1121) : const Color(0xFFE3F1EF),
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
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = isDark
          ? const Color(0x0D4FD1C5)
          : const Color(0x120A8F83);

    final circles = <Offset>[
      Offset(size.width * .12, size.height * .18),
      Offset(size.width * .88, size.height * .34),
      Offset(size.width * .24, size.height * .78),
      Offset(size.width * .76, size.height * .88),
    ];

    for (final center in circles) {
      canvas.drawCircle(center, size.shortestSide * .22, paint);
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = isDark
          ? const Color(0x0AFFFFFF)
          : const Color(0x0A263238);

    final step = size.width / 8;
    for (var x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChatBackgroundPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
