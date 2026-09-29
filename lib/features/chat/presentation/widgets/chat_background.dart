import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ChatBackground extends StatelessWidget {
  final Widget child;

  const ChatBackground({
    super.key,
    required this.child,
  });

  static const String _lightWallpaper =
      'assets/images/sehatak_chat_wallpaper_light.svg';
  static const String _darkWallpaper =
      'assets/images/sehatak_chat_wallpaper_dark.svg';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wallpaper = isDark ? _darkWallpaper : _lightWallpaper;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(
              color: isDark
                  ? const Color(0xFF0B1121)
                  : const Color(0xFFE3F1EF),
              child: ColorFiltered(
                colorFilter: isDark
                    ? const ColorFilter.mode(
                        Color(0x00000000), BlendMode.srcOver)
                    : const ColorFilter.mode(
                        Color(0x120A8F83), BlendMode.multiply),
                child: SvgPicture.asset(
                  wallpaper,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
