import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:memochat/core/constants/app_colors.dart';
import 'package:memochat/features/chat/presentation/widgets/audio_waveform_bubble.dart';
import 'package:memochat/features/chat/presentation/widgets/media_viewer.dart';
import 'package:memochat/features/games/presentation/game_room_screen.dart';

class MessageBubble extends StatefulWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;
  final Function(String)? onReaction;
  final VoidCallback? onPin;
  final VoidCallback? onDeleteForMe;
  final VoidCallback? onEdit;
  final bool isFirstInChat;
  final VoidCallback? onReplyPreviewTap;
  final VoidCallback? onForward;
  final VoidCallback? onStar;
  final VoidCallback? onSelect;
  final void Function(String type)? onCallAgain;
  final double fontSize;

  const MessageBubble({super.key, required this.message, required this.isMe, this.onReply, this.onDelete, this.onReaction, this.onPin, this.onDeleteForMe, this.onEdit, this.isFirstInChat = false, this.onReplyPreviewTap, this.onForward, this.onStar, this.onSelect, this.onCallAgain, this.fontSize = 14});

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MemoBubblePainter extends CustomPainter {
  final bool isMe;
  final bool dark;
  final bool emphasized;

  const _MemoBubblePainter({
    required this.isMe,
    required this.dark,
    required this.emphasized,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = isMe
          ? AppColors.primary
          : (dark ? const Color(0xFF10201E) : Colors.white);

    // The small lower-side notch is MemoChat's visual signature:
    // asymmetric, quiet, and intentionally unlike the standard chat tail.
    final r = emphasized ? 18.0 : 15.0;
    final path = Path();
    if (isMe) {
      path
        ..moveTo(r, 0)
        ..lineTo(size.width - 6, 0)
        ..quadraticBezierTo(size.width, 0, size.width, r)
        ..lineTo(size.width, size.height - 16)
        ..quadraticBezierTo(size.width, size.height - 5, size.width - 8, size.height - 4)
        ..lineTo(size.width - 1, size.height)
        ..lineTo(size.width - 17, size.height - 5)
        ..lineTo(16, size.height - 5)
        ..quadraticBezierTo(0, size.height - 5, 0, size.height - 20)
        ..lineTo(0, r)
        ..quadraticBezierTo(0, 0, r, 0);
    } else {
      path
        ..moveTo(6, 0)
        ..lineTo(size.width - r, 0)
        ..quadraticBezierTo(size.width, 0, size.width, r)
        ..lineTo(size.width, size.height - 20)
        ..quadraticBezierTo(size.width, size.height - 5, size.width - 16, size.height - 5)
        ..lineTo(8, size.height - 5)
        ..lineTo(1, size.height)
        ..lineTo(16, size.height - 4)
        ..quadraticBezierTo(0, size.height - 5, 0, size.height - 20)
        ..lineTo(0, r)
        ..quadraticBezierTo(0, 0, 6, 0);
    }
    canvas.drawPath(path, paint);

    if (!isMe && !dark) {
      final border = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = const Color(0xFFDCE5E3);
      canvas.drawPath(path, border);
    }
  }

  @override
  bool shouldRepaint(covariant _MemoBubblePainter oldDelegate) =>
      oldDelegate.isMe != isMe ||
      oldDelegate.dark != dark ||
      oldDelegate.emphasized != emphasized;
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _isLocal(String path) => widget.message['isLocal'] == true || widget.message['isUploading'] == true || path.startsWith('file://') || (path.isNotEmpty && !path.startsWith('http') && File(path).existsSync());



  Future<void> _sendToAnotherChat(File file) async {
    try {
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      debugPrint('share message failed: $e');
    }
  }

  Future<void> _showMessageInfo() async {
    if (!mounted) return;
    final m = widget.message;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('معلومات الرسالة', textAlign: TextAlign.right, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              if (m['isEdited'] == true) _infoRow(Icons.edit_outlined, 'الحالة', 'تم تعديل الرسالة'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
          Text(value, textDirection: TextDirection.ltr),
        ]),
      );
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final type = (widget.message['type'] ?? 'text').toString();
    final progress = (widget.message['uploadProgress'] as num?)?.toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: widget.isMe ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .82),
          child: Stack(clipBehavior: Clip.none, children: [
            _buildContent(type, dark),
            if (progress != null && progress >= 0 && progress < 1) Positioned(left: 8, right: 8, bottom: 3, child: LinearProgressIndicator(value: progress, minHeight: 2)),
            if (widget.message['hasError'] == true) PositionedDirectional(start: -38, bottom: 5, child: IconButton(tooltip: 'إعادة المحاولة', onPressed: () => widget.message['onRetry']?.call(), icon: const Icon(Icons.refresh, color: Colors.red, size: 22))),
          ]),
        ),
      ),
    );
  }

  Widget _shell(Widget child, bool dark) => GestureDetector(
        onLongPress: widget.onSelect ?? _options,
        child: CustomPaint(
          painter: _MemoBubblePainter(
            isMe: widget.isMe,
            dark: dark,
            emphasized: widget.isFirstInChat,
          ),
          child: Container(
            margin: EdgeInsetsDirectional.only(
              start: widget.isMe ? 4 : 0,
              end: widget.isMe ? 0 : 4,
            ),
            color: Colors.transparent,
            child: child,
          ),
        ),
      );
  Widget _buildContent(String type, bool dark) {
    final m = widget.message;
    switch (type) {
      case 'image':
        return _withStatus(_buildImage(m['imageUrl']?.toString() ?? m['fileUrl']?.toString() ?? m['text']?.toString() ?? ''));
      case 'video':
        return _withStatus(_buildVideo(m['videoUrl']?.toString() ?? m['fileUrl']?.toString() ?? m['text']?.toString() ?? ''));
      case 'audio':
        final url = m['audioUrl']?.toString() ?? m['fileUrl']?.toString() ?? m['text']?.toString() ?? '';
        // Keep the original opaque audio-message bubble appearance from 5777e10.
        // Delivery/read state remains an icon beside the bubble.
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          textDirection: widget.isMe ? TextDirection.ltr : TextDirection.rtl,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 7, bottom: 6),
              child: _mediaStatus(m),
            ),
            _shell(
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      AudioWaveformBubble(
                        audioUrl: url, isMe: widget.isMe, isLocal: _isLocal(url),
                      ),
                      PositionedDirectional(
                        top: 5, start: 7,
                        child: _mediaTypeChip(Icons.graphic_eq_rounded, 'صوت', dark),
                      ),
                    ],
                  ),
                  _mediaMeta(m, compact: true),
                ],
              ),
              dark,
            ),
          ],
        );
      case 'file':
        return _withStatus(_buildFile(m, dark));
      case 'location':
        return _withStatus(_buildLocation(m, dark));
      case 'contact':
        return _withStatus(_buildContact(m, dark));
      case 'game_invite':
      case 'gameInvite':
        return _buildGameInvite(m, dark);
      case 'system':
        return _buildSystem(m);
      default:
        return _buildText(m, dark);
    }
  }

  /// Delivery/read state is part of every message document, including media.
  /// Keep the same placement used by text messages: for received messages the
  /// status is rendered before the bubble; for sent messages it stays at the end.
  Widget _withStatus(Widget bubble) {
    final m = widget.message;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      textDirection: widget.isMe ? TextDirection.ltr : TextDirection.rtl,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 7, bottom: 6),
          child: _mediaStatus(m),
        ),
        bubble,
      ],
    );
  }

  /// Keep delivery/read state as icons only. The chat UI intentionally
  /// does not display textual status labels beside media messages.
  Widget _mediaStatus(Map<String, dynamic> m) {
    if (m['isSending'] == true) {
      return const Icon(Icons.schedule, size: 14, color: Colors.grey);
    }
    if (m['isRead'] == true) {
      return const Icon(Icons.done_all_rounded, size: 15, color: AppColors.primary);
    }
    if (m['isDelivered'] == true) {
      return const Icon(Icons.done_all_rounded, size: 15, color: Colors.grey);
    }
    return const Icon(Icons.done_rounded, size: 15, color: Colors.grey);
  }

  Widget _buildGameInvite(Map<String, dynamic> m, bool dark) {
    final metadata = m['metadata'] is Map
        ? Map<String, dynamic>.from(m['metadata'] as Map)
        : <String, dynamic>{};
    final gameId = metadata['gameId']?.toString() ?? '';
    final gameType = metadata['gameType']?.toString() ?? '';
    final title = m['text']?.toString().replaceFirst('دعوة تحدٍ: ', '') ?? 'تحدٍ مباشر';

    return _shell(
      Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.sports_esports_rounded,
                    color: widget.isMe ? Colors.white : AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: widget.isMe ? Colors.white : (dark ? Colors.white : const Color(0xFF20312F)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              widget.isMe ? 'أرسلت تحديًا مباشرًا مشفرًا' : 'وصلك تحدٍ مباشر مشفر عبر Signal',
              style: TextStyle(
                fontSize: 11,
                color: widget.isMe ? Colors.white70 : (dark ? Colors.white70 : Colors.black54),
              ),
            ),
            if (gameId.isNotEmpty) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GameRoomScreen(
                      chatId: m['chatId']?.toString() ?? '',
                      gameId: gameId,
                    ),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(widget.isMe ? 'فتح غرفة التحدي' : 'قبول التحدي'),
              ),
            ],
            if (gameType.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'اللعبة: $gameType',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    color: widget.isMe ? Colors.white54 : (dark ? Colors.white54 : Colors.black45),
                  ),
                ),
              ),
          ],
        ),
      ),
      dark,
    );
  }

  Widget _buildText(Map<String, dynamic> m, bool dark) {
    final bubble = _shell(Padding(
      padding: const EdgeInsets.fromLTRB(13, 9, 10, 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (m['isPinned'] == true) _pinnedMarker(dark),
          if (m['isEdited'] == true) _editedMarker(dark),
          if (m['replyPreview'] is Map) _replyPreview(m['replyPreview'] as Map, dark),
          Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Flexible(child: Text(m['text']?.toString() ?? '', style: TextStyle(color: widget.isMe ? Colors.white : (dark ? Colors.white : const Color(0xFF20312F)), fontSize: widget.fontSize))),
            const SizedBox(width: 6),
            Text(_timeLabel(m['timestamp'] ?? m['clientTimestamp']), style: TextStyle(color: widget.isMe ? Colors.white70 : (dark ? Colors.white60 : const Color(0xFF6B7D7D)), fontSize: 9)),
          ]),
          _reactions(m, dark),
        ],
      ),
    ), dark);
    // Show the delivery/read state on both sides of the conversation.
    // The status belongs to the message document itself, so the recipient can
    // also see the same ✓ / ✓✓ / read state instead of only the sender.
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      // Sender bubbles stay LTR so ✓✓ remains at the sender-side end.
      // Recipient bubbles are RTL so the read state is rendered first:
      // ✓✓ ثم الفقاعة, instead of appearing after the bubble.
      textDirection: widget.isMe ? TextDirection.ltr : TextDirection.rtl,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 7),
          child: _status(m),
        ),
        bubble,
      ],
    );
  }

  Widget _editedMarker(bool dark) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Text('معدلة', style: TextStyle(fontSize: 9, color: widget.isMe ? Colors.white60 : (dark ? Colors.white54 : Colors.grey))),
  );

  Widget _pinnedMarker(bool dark) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.push_pin_rounded, size: 13, color: widget.isMe ? Colors.white70 : AppColors.primary),
        const SizedBox(width: 4),
        Text('مثبتة', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: widget.isMe ? Colors.white70 : (dark ? Colors.white70 : const Color(0xFF49615E)))),
      ],
    ),
  );


  Widget _replyPreview(Map preview, bool dark) {
    final sender = preview['senderName']?.toString().trim() ?? 'مستخدم';
    final rawText =
        preview['text'] ?? preview['content'] ?? preview['message'] ?? preview['body'];
    final text = rawText?.toString().trim().isNotEmpty == true
        ? rawText.toString().trim()
        : _replyAttachmentPreview(preview);

    return GestureDetector(
      onTap: widget.onReplyPreviewTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: widget.isMe
              ? Colors.white.withOpacity(.14)
              : (dark ? Colors.black.withOpacity(.16) : const Color(0xFFEAF5F3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sender,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: widget.isMe ? Colors.white : AppColors.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: widget.isMe
                    ? Colors.white70
                    : (dark ? Colors.white70 : const Color(0xFF49615E)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _replyAttachmentPreview(Map preview) {
    switch (preview['type']?.toString()) {
      case 'image': return 'صورة';
      case 'video': return 'فيديو';
      case 'audio': return 'رسالة صوتية';
      case 'file': return 'ملف';
      case 'location': return 'موقع';
      default: return 'مرفق';
    }
  }


  String _timeLabel(dynamic value) { final DateTime? date = value is Timestamp ? value.toDate() : value is DateTime ? value : value is String ? DateTime.tryParse(value) : null; if (date == null) return ''; final h = date.hour.toString().padLeft(2, '0'); final min = date.minute.toString().padLeft(2, '0'); return '$h:$min'; }

  Widget _status(Map<String, dynamic> m) {
    final onMe = widget.isMe;
    final base = onMe ? Colors.white70 : (darkenForStatus(context) ? Colors.white60 : const Color(0xFF60736F));
    if (m['hasError'] == true) {
      return const Icon(Icons.error_outline_rounded, size: 15, color: Colors.redAccent);
    }
    if (m['isSending'] == true) {
      return Icon(Icons.schedule_rounded, size: 14, color: base);
    }
    if (m['isRead'] == true) {
      return const Icon(Icons.done_all_rounded, size: 15, color: AppColors.primary);
    }
    if (m['isDelivered'] == true) {
      return Icon(Icons.done_all_rounded, size: 15, color: base);
    }
    return Icon(Icons.done_rounded, size: 15, color: base);
  }

  bool darkenForStatus(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  Widget _reactions(Map<String, dynamic> m, bool dark) {
    final raw = m['reactions'];
    if (raw is! Map || raw.isEmpty) return const SizedBox.shrink();
    final counts = <String, int>{};
    for (final value in raw.values) { final emoji = value.toString(); counts[emoji] = (counts[emoji] ?? 0) + 1; }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 3,
        children: counts.entries.map((entry) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(color: dark ? Colors.white12 : Colors.black12, borderRadius: BorderRadius.circular(10)),
          child: Text('${entry.key} ${entry.value}', style: const TextStyle(fontSize: 10)),
        )).toList(),
      ),
    );
  }

  Widget _mediaTypeChip(IconData icon, String label, bool dark) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.48),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white.withOpacity(.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }

  Widget _uploadChip(Map<String, dynamic> m, bool dark) {
    final progress = (m['uploadProgress'] as num?)?.toDouble();
    final label = progress != null
        ? '${(progress.clamp(0, 1) * 100).round()}%'
        : 'جارٍ الإرسال';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: (widget.isMe ? Colors.black : AppColors.primary).withOpacity(.72),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 11, height: 11,
            child: CircularProgressIndicator(strokeWidth: 1.6, color: Colors.white)),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }

  Widget _mediaMeta(Map<String, dynamic> m, {bool compact = false}) {
    final name = m['fileName']?.toString().trim() ?? '';
    final size = m['fileSize']?.toString().trim() ?? '';
    final mime = m['fileMimeType']?.toString().trim() ?? '';
    final duration = m['audioDuration']?.toString().trim() ?? '';
    final type = m['type']?.toString() ?? '';
    final parts = <String>[];
    if (name.isNotEmpty) parts.add(name);
    if (size.isNotEmpty) parts.add(size);
    if (mime.isNotEmpty && name.isEmpty) parts.add(mime);
    if (type == 'audio' && duration.isNotEmpty) parts.add(duration);
    if (parts.isEmpty) return const SizedBox.shrink();
    final tc = widget.isMe
        ? Colors.white70
        : (Theme.of(context).brightness == Brightness.dark
            ? Colors.white60
            : const Color(0xFF617370));
    return Padding(
      padding: EdgeInsets.only(top: compact ? 4 : 6),
      child: Text(
        parts.join(' • '),
        maxLines: compact ? 1 : 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: tc, fontSize: compact ? 9 : 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildImage(String path) {
    final m = widget.message;
    if (path.isEmpty) {
      return _shell(
        const SizedBox(width: 230, height: 100, child: Center(child: Icon(Icons.broken_image_outlined))),
        Theme.of(context).brightness == Brightness.dark,
      );
    }
    final local = _isLocal(path);
    final cleanPath = path.replaceFirst('file://', '');
    final image = local
        ? Image.file(File(cleanPath), fit: BoxFit.contain)
        : CachedNetworkImage(imageUrl: path, fit: BoxFit.contain);
    final mediaDark = Theme.of(context).brightness == Brightness.dark;
    final preview = ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: Stack(
        alignment: Alignment.center,
        children: [
          local
              ? Image.file(File(cleanPath), width: 230, height: 230, fit: BoxFit.cover)
              : CachedNetworkImage(
                  imageUrl: path,
                  width: 230,
                  height: 230,
                  fit: BoxFit.cover,
              placeholder: (_, __) => const SizedBox(
                width: 230, height: 230,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (_, __, ___) => const SizedBox(
                width: 230, height: 230,
                child: Center(child: Icon(Icons.broken_image_outlined)),
              ),
          PositionedDirectional(
            top: 8,
            start: 8,
            child: _mediaTypeChip(Icons.photo_outlined, 'صورة', mediaDark),
          ),
          if (m['isUploading'] == true)
            PositionedDirectional(
              bottom: 8,
              start: 8,
              child: _uploadChip(m, mediaDark),
            ),
        ],
      ),
    );
    return GestureDetector(
      onTap: () async {
        if (!local && path.startsWith('http')) {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => MediaViewer(mediaUrl: path, mediaType: 'image')),
          );
        } else if (mounted) {
          await showDialog<void>(
            context: context,
            barrierColor: Colors.black87,
            builder: (_) => Dialog(
              backgroundColor: Colors.transparent,
              child: InteractiveViewer(child: image),
            ),
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [preview, _mediaMeta(m, compact: true)],
      ),
    );
  }

  Widget _buildVideo(String path) {
    if (path.isEmpty) {
      return const SizedBox(
        width: 230,
        height: 100,
        child: Center(child: Text('تعذر تحميل الفيديو')),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: _InlineVideoPreview(
                url: path,
                isLocal: _isLocal(path),
          onOpen: () => showDialog<void>(
            context: context,
            barrierColor: Colors.black87,
            builder: (_) => _VideoViewer(url: path, isLocal: _isLocal(path)),
          ),
                ),
              ),
            PositionedDirectional(
              top: 8,
              start: 8,
              child: _mediaTypeChip(Icons.play_circle_outline_rounded, 'فيديو',
                  Theme.of(context).brightness == Brightness.dark),
            ),
            if (widget.message['isUploading'] == true)
              PositionedDirectional(
                bottom: 8,
                start: 8,
                child: _uploadChip(widget.message,
                    Theme.of(context).brightness == Brightness.dark),
              ),
          ],
        ),
        _mediaMeta(widget.message, compact: true),
      ],
    );
  }

  Widget _buildFile(Map<String, dynamic> m, bool dark) {
    final url = m['fileUrl']?.toString() ?? m['text']?.toString() ?? '';
    final name = (m['fileName']?.toString().trim().isNotEmpty == true)
        ? m['fileName'].toString()
        : 'ملف';
    final mime = (m['fileMimeType']?.toString() ?? '').toLowerCase();
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    final isPdf = ext == 'pdf' || mime == 'application/pdf';
    final isText = {'txt','text','log','csv','md'}.contains(ext) || mime.startsWith('text/');
    final isOffice = {'doc','docx','xls','xlsx','ppt','pptx'}.contains(ext) ||
        mime.contains('word') || mime.contains('spreadsheet') || mime.contains('presentation');
    final tc = widget.isMe ? Colors.white : (dark ? Colors.white : const Color(0xFF20312F));

    Future<File?> downloadRemote() async {
      if (url.isEmpty || _isLocal(url)) return File(url.replaceFirst('file://', ''));
      try {
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
        if (response.statusCode < 200 || response.statusCode >= 300) return null;
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${DateTime.now().microsecondsSinceEpoch}_$name');
        await file.writeAsBytes(response.bodyBytes, flush: true);
        return file;
      } catch (_) {
        return null;
      }
    }


    Future<void> documentActions() async {
      if (url.isEmpty) return;
      final action = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.visibility_outlined), title: const Text('فتح المستند'), onTap: () => Navigator.pop(ctx, 'open')),
          ListTile(leading: const Icon(Icons.share_outlined), title: const Text('مشاركة / إرسال خارج التطبيق'), onTap: () => Navigator.pop(ctx, 'share')),
          ListTile(leading: const Icon(Icons.save_alt_outlined), title: const Text('حفظ في المكتبة'), onTap: () => Navigator.pop(ctx, 'library')),
          ListTile(leading: const Icon(Icons.download_outlined), title: const Text('حفظ نسخة على الهاتف'), onTap: () => Navigator.pop(ctx, 'download')),
          ListTile(leading: const Icon(Icons.send_outlined), title: const Text('إرسال إلى دردشة أخرى'), onTap: () => Navigator.pop(ctx, 'chat')),
        ])),
      );
      if (action == null) return;
      final file = await downloadRemote();
      if (file == null) { _showFileError(); return; }
      if (action == 'open') {
        if (isPdf || isOffice) {
          if (mounted) await showDialog<void>(context: context, builder: (_) => _DocumentWebViewDialog(title: name, url: url));
        } else if (isText) {
          final text = await file.readAsString();
          if (mounted) await showDialog<void>(context: context, builder: (_) => _TextDocumentDialog(title: name, content: text));
        }
      } else if (action == 'share' || action == 'download') {
        await Share.shareXFiles([XFile(file.path)], text: action == 'download' ? 'نسخة محفوظة من الملف' : 'ملف من المحادثة');
      } else if (action == 'library') {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance.collection('document_library').doc().set({
            'ownerId': uid, 'chatId': m['chatId'], 'fileName': name,
            'fileUrl': url, 'mimeType': mime, 'savedAt': FieldValue.serverTimestamp(),
          });
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ المستند في المكتبة.')));
        }
      } else if (action == 'chat') {
        await _sendToAnotherChat(file);
      }
    }

    Future<void> open() async {
      if (url.isEmpty) return;
      if (_isLocal(url)) {
        final localUri = Uri.file(url.replaceFirst('file://', ''));
        if (isText) {
          try {
            final text = await File(localUri.toFilePath()).readAsString();
            if (mounted) await showDialog<void>(context: context, builder: (_) => _TextDocumentDialog(title: name, content: text));
          } catch (_) { if (mounted) _showFileError(); }
        } else if (await canLaunchUrl(localUri)) {
          await launchUrl(localUri, mode: LaunchMode.externalApplication);
        }
        return;
      }
      if (isText) {
        try {
          final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
          if (response.statusCode >= 200 && response.statusCode < 300 && mounted) {
            await showDialog<void>(context: context, builder: (_) => _TextDocumentDialog(title: name, content: response.body));
            return;
          }
        } catch (_) {}
        if (mounted) _showFileError();
        return;
      }
      if (isPdf || isOffice) {
        await documentActions();
        return;
      }
      final target = Uri.tryParse(url);
      if (target != null && await canLaunchUrl(target)) {
        await launchUrl(target, mode: LaunchMode.externalApplication);
      } else if (mounted) _showFileError();
    }

    return _shell(
      InkWell(
        onTap: open,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46, height: 46, alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.isMe ? Colors.white.withOpacity(.14)
                      : (dark ? Colors.white.withOpacity(.08) : const Color(0xFFEAF5F3)),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  isPdf ? Icons.picture_as_pdf_outlined
                      : isText ? Icons.article_outlined
                      : isOffice ? Icons.description_outlined
                      : Icons.insert_drive_file_outlined,
                  color: isPdf ? Colors.redAccent : tc, size: 25,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: tc, fontWeight: FontWeight.w700)),
                  _mediaMeta(m),
                ],
              )),
              const SizedBox(width: 8),
              Icon(isPdf || isText || isOffice ? Icons.visibility_outlined : Icons.download_for_offline, color: tc),
            ],
          ),
        ),
      ),
      dark,
    );
  }

  void _showFileError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح الملف حالياً. حاول مرة أخرى.')));
  }

  Widget _buildCall(Map<String, dynamic> m, bool dark) {
    final meta = m['metadata'] is Map ? Map<String, dynamic>.from(m['metadata'] as Map) : <String, dynamic>{};
    final status = (meta['status'] ?? '').toString().toLowerCase();
    final video = meta['isVideo'] == true || meta['callType']?.toString() == 'video';
    final duration = (meta['duration'] ?? '').toString().trim();
    final incoming = !widget.isMe;

    late final IconData icon;
    late final String statusLabel;
    switch (status) {
      case 'ended':
        icon = incoming ? Icons.call_received_rounded : Icons.call_made_rounded;
        statusLabel = duration.isNotEmpty ? 'تم الرد • $duration' : 'تم الرد';
        break;
      case 'missed':
        icon = Icons.call_missed_rounded;
        statusLabel = incoming ? 'لم يُرد عليها' : 'لم يُجب عليها';
        break;
      case 'rejected':
        icon = Icons.call_missed_rounded;
        statusLabel = incoming ? 'مرفوضة' : 'تم رفضها';
        break;
      case 'busy':
        icon = Icons.call_end_rounded;
        statusLabel = 'مشغول بمكالمة أخرى';
        break;