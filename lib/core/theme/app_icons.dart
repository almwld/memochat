import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Canonical MemoChat icon definition. SVG files are the visual source of truth.
class AppIconData {
  const AppIconData(this.name, this.assetPath, this.semanticLabel);

  final String name;
  final String assetPath;
  final String semanticLabel;
}

abstract final class AppIcons {
  static const chat = AppIconData('chat', 'assets/icons/chat.svg', 'محادثة');
  static const message = AppIconData('message', 'assets/icons/message.svg', 'رسالة');
  static const send = AppIconData('send', 'assets/icons/send.svg', 'إرسال');
  static const reply = AppIconData('reply', 'assets/icons/reply.svg', 'رد');
  static const forward = AppIconData('forward', 'assets/icons/forward.svg', 'إعادة إرسال');
  static const attachment = AppIconData('attachment', 'assets/icons/attachment.svg', 'مرفق');
  static const image = AppIconData('image', 'assets/icons/image.svg', 'صورة');
  static const video = AppIconData('video', 'assets/icons/video.svg', 'فيديو');
  static const audio = AppIconData('audio', 'assets/icons/audio.svg', 'صوت');
  static const file = AppIconData('file', 'assets/icons/file.svg', 'ملف');
  static const microphone = AppIconData('microphone', 'assets/icons/microphone.svg', 'ميكروفون');
  static const camera = AppIconData('camera', 'assets/icons/camera.svg', 'كاميرا');
  static const phoneCall = AppIconData('phone_call', 'assets/icons/phone_call.svg', 'مكالمة صوتية');
  static const videoCall = AppIconData('video_call', 'assets/icons/video_call.svg', 'مكالمة فيديو');
  static const contacts = AppIconData('contacts', 'assets/icons/contacts.svg', 'جهات الاتصال');
  static const notifications = AppIconData('notifications', 'assets/icons/notifications.svg', 'الإشعارات');
  static const search = AppIconData('search', 'assets/icons/search.svg', 'البحث');
  static const settings = AppIconData('settings', 'assets/icons/settings.svg', 'الإعدادات');
  static const profile = AppIconData('profile', 'assets/icons/profile.svg', 'الملف الشخصي');
  static const more = AppIconData('more', 'assets/icons/more.svg', 'المزيد');

  static const all = <AppIconData>[
    chat, message, send, reply, forward, attachment, image, video, audio, file,
    microphone, camera, phoneCall, videoCall, contacts, notifications, search,
    settings, profile, more,
  ];
}

class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  final AppIconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? IconTheme.of(context).color;
    return Semantics(
      label: semanticLabel ?? icon.semanticLabel,
      image: true,
      child: SvgPicture.asset(
        icon.assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorFilter: effectiveColor == null
            ? null
            : ColorFilter.mode(effectiveColor, BlendMode.srcIn),
      ),
    );
  }
}
