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
    final base = color ?? scheme.primaryContainer;
    final iconColor = color == null ? scheme.primary : scheme.onPrimaryContainer;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(size * .30),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Center(
        child: AppIcon(
          icon,
          size: iconSize,
          color: iconColor,
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
      padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 16, 18),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          PremiumIconTile(icon: icon, size: 56, iconSize: 27),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                )),
                const SizedBox(height: 5),
                Text(subtitle, style: TextStyle(
                  color: scheme.onPrimaryContainer.withOpacity(.78),
                  height: 1.45,
                  fontSize: 12.5,
                )),
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
          CustomPaint(
            painter: _ChatWallpaperPainter(
              Theme.of(context).brightness,
              Theme.of(context).colorScheme,
            ),
          ),
          child,
        ],
      );
}

class _ChatWallpaperPainter extends CustomPainter {
  const _ChatWallpaperPainter(this.brightness, this.scheme);
  final Brightness brightness;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = scheme.surface);
    final mark = Paint()
      ..color = scheme.primary.withOpacity(
        brightness == Brightness.dark ? .035 : .028,
      );
    for (var row = -1; row < 9; row++) {
      for (var col = -1; col < 7; col++) {
        final dx = col * 108.0 + (row.isEven ? 26 : 0);
        final dy = row * 92.0;
        canvas.drawCircle(Offset(dx, dy), 28, mark);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChatWallpaperPainter oldDelegate) =>
      oldDelegate.brightness != brightness || oldDelegate.scheme != scheme;
}

class ScrollAwareScaffold extends StatefulWidget {
  const ScrollAwareScaffold({
    required this.appBar,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    super.key,
  });

  final PreferredSizeWidget appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;

  @override
  State<ScrollAwareScaffold> createState() => _ScrollAwareScaffoldState();
}

class _ScrollAwareScaffoldState extends State<ScrollAwareScaffold> {
  bool _visible = true;

  bool _handleScroll(UserScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    final next = n.metrics.pixels <= 0 ||
        n.direction == ScrollDirection.forward;
    if (next != _visible && mounted) setState(() => _visible = next);
    return false;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: PreferredSize(
          preferredSize: widget.appBar.preferredSize,
          child: AnimatedSlide(
            offset: _visible ? Offset.zero : const Offset(0, -1),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: widget.appBar,
          ),
        ),
        body: NotificationListener<UserScrollNotification>(
          onNotification: _handleScroll,
          child: widget.body,
        ),
        floatingActionButton: widget.floatingActionButton,
        bottomNavigationBar: widget.bottomNavigationBar,
        backgroundColor: widget.backgroundColor,
        resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      );
}