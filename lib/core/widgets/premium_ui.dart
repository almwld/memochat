import 'package:flutter/material.dart';
import '../theme/app_icons.dart';

class PremiumIconTile extends StatelessWidget {
  const PremiumIconTile({
    required this.icon,
    this.size = 52,
    this.iconSize = 25,
    this.color,
    this.semanticLabel,
    super.key,
  });

  final AppIconData icon;
  final double size;
  final double iconSize;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = color ?? scheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(base, Colors.white, .38)!,
            base,
            Color.lerp(base, Colors.black, .16)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: base.withOpacity(.22),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(.34),
            blurRadius: 3,
            offset: const Offset(-1, -2),
          ),
        ],
      ),
      child: Center(
        child: AppIcon(
          icon,
          size: iconSize,
          color: Colors.white,
          semanticLabel: semanticLabel,
        ),
      ),
    );
  }
}

class PremiumHero extends StatelessWidget {
  const PremiumHero({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.action,
    super.key,
  });

  final String title;
  final String subtitle;
  final AppIconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, const Color(0xFF073B36), .42)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(.22),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          PremiumIconTile(
            icon: icon,
            color: Colors.white.withOpacity(.18),
            size: 58,
            iconSize: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.45,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class ChatWallpaper extends StatelessWidget {
  const ChatWallpaper({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _ChatWallpaperPainter()),
          child,
        ],
      );
}

class _ChatWallpaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    paint.shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFEAF8F5), Color(0xFFF7FBFA), Color(0xFFEAF3F1)],
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);

    final bubble = Paint()..color = const Color(0xFF0A8F83).withOpacity(.035);
    for (var row = -1; row < 8; row++) {
      for (var col = -1; col < 6; col++) {
        final dx = col * 105.0 + (row.isEven ? 28 : 0);
        final dy = row * 88.0;
        canvas.drawCircle(Offset(dx, dy), 34, bubble);
      }
    }

    final line = Paint()
      ..color = const Color(0xFF0A8F83).withOpacity(.025)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < 10; i++) {
      final path = Path()
        ..moveTo(0, i * 95.0)
        ..quadraticBezierTo(size.width * .5, i * 95.0 - 30, size.width, i * 95.0 + 18);
      canvas.drawPath(path, line);
    }
  }

  @override
  bool shouldRepaint(covariant _ChatWallpaperPainter oldDelegate) => false;
}
