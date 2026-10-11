import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:memochat/core/constants/app_colors.dart';

/// Compact Gemini-inspired typing animation: three luminous points orbiting
/// together in a triangular formation while the sender is composing a message.
class TypingIndicator extends StatefulWidget {
  final String name;

  const TypingIndicator({
    super.key,
    this.name = '',
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1450),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;
    final orbitColor = isDark ? const Color(0xFF73D7CC) : AppColors.primary;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 7, 16, 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.name.isNotEmpty) ...[
            Flexible(
              child: Text(
                widget.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            'يكتب',
            style: TextStyle(color: labelColor, fontSize: 12),
          ),
          const SizedBox(width: 7),
          SizedBox(
            width: 23,
            height: 23,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => CustomPaint(
                painter: _OrbitingTrianglePainter(
                  progress: _controller.value,
                  color: orbitColor,
                  glowColor: orbitColor.withOpacity(isDark ? .28 : .18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbitingTrianglePainter extends CustomPainter {
  const _OrbitingTrianglePainter({
    required this.progress,
    required this.color,
    required this.glowColor,
  });

  final double progress;
  final Color color;
  final Color glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * .34;
    final rotation = progress * math.pi * 2 - math.pi / 2;
    final points = List<Offset>.generate(3, (index) {
      final angle = rotation + index * math.pi * 2 / 3;
      return Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
    });

    // A faint triangular path keeps the three points visually connected.
    final path = Path()
      ..moveTo(points[0].dx, points[0].dy)
      ..lineTo(points[1].dx, points[1].dy)
      ..lineTo(points[2].dx, points[2].dy)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(.24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );

    for (var i = 0; i < points.length; i++) {
      final pulse = .8 + .2 * math.sin(progress * math.pi * 4 + i * 1.8);
      final dotRadius = 2.4 * pulse;
      canvas.drawCircle(
        points[i],
        dotRadius + 1.5,
        Paint()
          ..color = glowColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
      canvas.drawCircle(
        points[i],
        dotRadius,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitingTrianglePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.glowColor != glowColor;
}
