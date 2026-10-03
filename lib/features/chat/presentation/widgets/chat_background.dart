import 'package:flutter/material.dart';

class ChatBackground extends StatelessWidget {
  const ChatBackground({
    super.key,
    required this.child,
    this.scrollController,
    this.wallpaper = 'default',
  });

  final Widget child;
  final ScrollController? scrollController;
  final String wallpaper;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: _backgroundColor(dark),
          child: CustomPaint(
            painter: _ChatBackgroundPainter(dark: dark, wallpaper: wallpaper, scrollOffset: scrollController?.hasClients == true ? scrollController!.offset : 0),
          ),
        ),
        child,
      ],
    );
  }

  Color _backgroundColor(bool dark) => switch (wallpaper) {
    'mint' => dark ? const Color(0xFF102824) : const Color(0xFFE8F6F2),
    'paper' => dark ? const Color(0xFF171717) : const Color(0xFFFFFBF2),
    'dark' => const Color(0xFF0B1117),
    _ => dark ? const Color(0xFF0B1117) : const Color(0xFFF4F7F6),
  };
}

class _ChatBackgroundPainter extends CustomPainter {
  const _ChatBackgroundPainter({required this.dark, required this.scrollOffset, required this.wallpaper});

  final bool dark;
  final double scrollOffset;
  final String wallpaper;

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()
      ..style = PaintingStyle.fill
      ..color = dark ? const Color(0x14FFFFFF) : const Color(0x183D5B56);

    const spacing = 44.0;
    final verticalShift = (scrollOffset * .08) % spacing;
    for (var y = 18.0 - verticalShift; y < size.height + spacing; y += spacing) {
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
      oldDelegate.dark != dark || oldDelegate.scrollOffset != scrollOffset || oldDelegate.wallpaper != wallpaper;
}
