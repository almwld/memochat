import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
          preferredSize: Size.fromHeight(_visible ? widget.appBar.preferredSize.height : 0),
          child: ClipRect(child: AnimatedSlide(
            offset: _visible ? Offset.zero : const Offset(0, -1),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: widget.appBar,
          )),
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

/// Shared MemoChat surface primitives. Keep screen-level styling consistent
/// without coupling feature logic to a particular page.
class MemoSectionLabel extends StatelessWidget {
  const MemoSectionLabel(this.title, {this.action, super.key});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 18, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class MemoListCard extends StatelessWidget {
  const MemoListCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 10, 12),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Icon(icon, color: scheme.primary, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    )),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null) ...[const SizedBox(width: 8), badge!],
              const SizedBox(width: 4),
              Icon(Icons.chevron_left_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class MemoPageHeader extends StatelessWidget {
  const MemoPageHeader({
    required this.title,
    required this.subtitle,
    this.icon,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
      child: Row(
        children: [
          if (icon != null) ...[
            PremiumIconTile(icon: _iconData(icon!), size: 44, iconSize: 21),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                )),
                const SizedBox(height: 5),
                Text(subtitle, style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12.5,
                  height: 1.35,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  AppIconData _iconData(IconData icon) {
    if (icon == Icons.search) return AppIcons.search;
    if (icon == Icons.chat_bubble_outline_rounded) return AppIcons.chat;
    if (icon == Icons.contacts) return AppIcons.contacts;
    if (icon == Icons.settings_outlined) return AppIcons.settings;
    return AppIcons.chat;
  }
}
