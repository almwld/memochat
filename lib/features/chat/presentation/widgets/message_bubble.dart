import 'dart:io';
import 'dart:ui' as ui;

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

    // WhatsApp-inspired palette: pale sage outgoing bubbles in light mode,
    // deep green outgoing bubbles in dark mode, and neutral incoming bubbles.
    final color = isMe
        ? (dark ? const Color(0xFF005C4B) : const Color(0xFFD9FDD3))
        : (dark ? const Color(0xFF202C33) : const Color(0xFFFFFFFF));
    final paint = Paint()..style = PaintingStyle.fill..color = color;
    final r = emphasized ? 17.0 : 12.0;
    const tail = 7.0;
    final path = ui.Path();

    if (isMe) {
      path
        ..moveTo(r, 0)
        ..lineTo(size.width - r, 0)
        ..quadraticBezierTo(size.width, 0, size.width, r)
        ..lineTo(size.width, size.height - r)
        ..quadraticBezierTo(size.width, size.height, size.width - r, size.height)
        ..lineTo(14, size.height)
        ..lineTo(size.width - 1, size.height - 1)
        ..lineTo(size.width - tail, size.height - 8)
        ..lineTo(r, size.height)
        ..quadraticBezierTo(0, size.height, 0, size.height - r)
        ..lineTo(0, r)
        ..quadraticBezierTo(0, 0, r, 0);
    } else {
      path
        ..moveTo(r, 0)
        ..lineTo(size.width - r, 0)
        ..quadraticBezierTo(size.width, 0, size.width, r)
        ..lineTo(size.width, size.height - r)
        ..quadraticBezierTo(size.width, size.height, size.width - r, size.height)
        ..lineTo(14, size.height)
        ..lineTo(tail, size.height - 1)
        ..lineTo(tail + 5, size.height - 8)
        ..lineTo(r, size.height)
        ..quadraticBezierTo(0, size.height, 0, size.height - r)
        ..lineTo(0, r)
        ..quadraticBezierTo(0, 0, r, 0);
    }

    canvas.drawPath(path, paint);
    if (!isMe && !dark) {
      final border = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .45
        ..color = const Color(0xFFE7EDEF);
      canvas.drawPath(path, border);
    }
  }

  @override
  bool shouldRepaint(covariant _MemoBubblePainter oldDelegate) =>
      oldDelegate.isMe != isMe ||
      oldDelegate.dark != dark ||
      oldDelegate.emphasized != emphasized;
}

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
            constraints: const BoxConstraints(minWidth: 44),
            margin: EdgeInsetsDirectional.only(
              start: widget.isMe ? 3 : 0,
              end: widget.isMe ? 0 : 3,
            ),
            padding: const EdgeInsets.symmetric(vertical: 1),
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
                        audioUrl: url,
                        isMe: widget.isMe,
                        isLocal: _isLocal(url),
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
      return const Icon(Icons.done_all_rounded, size: 15, color: const Color(0xFF53BDEB));
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
                      color: dark ? Colors.white : const Color(0xFF111B21),
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
            Flexible(child: Text(m['text']?.toString() ?? '', style: TextStyle(color: dark ? Colors.white : const Color(0xFF111B21), fontSize: widget.fontSize))),
            const SizedBox(width: 6),
            Text(_timeLabel(m['timestamp'] ?? m['clientTimestamp']), style: TextStyle(color: dark ? Colors.white60 : const Color(0xFF667781), fontSize: 9)),
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
    if (m['isSending'] == true) return const Icon(Icons.schedule, size: 14, color: Colors.grey);
    if (m['isRead'] == true) return const Icon(Icons.done_all_rounded, size: 15, color: const Color(0xFF53BDEB));
    if (m['isDelivered'] == true) return const Icon(Icons.done_all_rounded, size: 15, color: Colors.grey);
    return const Icon(Icons.done_rounded, size: 15, color: Colors.grey);
  }

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
          const SizedBox(width: 11, height: 11, child: CircularProgressIndicator(strokeWidth: 1.6, color: Colors.white)),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }

  Widget _mediaMeta(Map<String, dynamic> m, {bool compact = false}) {
    final type = m['type']?.toString() ?? '';
    final rawName = m['fileName']?.toString().trim() ?? '';
    final rawSize = m['fileSize']?.toString().trim() ?? '';
    final mime = m['fileMimeType']?.toString().trim() ?? '';
    final duration = m['audioDuration']?.toString().trim() ?? '';
    final parts = <String>[];

    if (type == 'audio') {
      // Voice notes show human-readable details only; never expose storage IDs
      // or generated .m4a filenames in the conversation UI.
      if (duration.isNotEmpty) {
        final seconds = int.tryParse(duration);
        if (seconds != null && seconds >= 0) {
          parts.add('${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}');
        } else {
          parts.add(duration);
        }
      }
      final bytes = int.tryParse(rawSize.replaceAll(RegExp(r'[^0-9]'), ''));
      if (bytes != null && bytes > 0) {
        parts.add(bytes < 1024
            ? '${bytes} B'
            : '${(bytes / 1024).round()} KB');
      } else if (rawSize.isNotEmpty) {
        parts.add(rawSize);
      }
    } else {
      if (rawName.isNotEmpty) parts.add(rawName);
      if (rawSize.isNotEmpty) parts.add(rawSize);
      if (mime.isNotEmpty && rawName.isEmpty) parts.add(mime);
    }
    if (parts.isEmpty) return const SizedBox.shrink();

    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = widget.isMe
        ? Colors.white70
        : (dark ? Colors.white70 : const Color(0xFF617370));
    final background = widget.isMe
        ? Colors.white.withOpacity(.10)
        : (dark ? Colors.white.withOpacity(.08) : const Color(0xFFEAF5F3));
    final icon = switch (type) {
      'audio' => Icons.graphic_eq_rounded,
      'video' => Icons.videocam_outlined,
      'image' => Icons.photo_outlined,
      'file' => Icons.insert_drive_file_outlined,
      'location' => Icons.location_on_outlined,
      _ => Icons.info_outline_rounded,
    };

    return Padding(
      padding: EdgeInsets.only(top: compact ? 3 : 7),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: compact ? 11 : 12, color: foreground),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  parts.join(' • '),
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: compact ? 9 : 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(String path) {
    final m = widget.message;
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (path.isEmpty) {
      return _shell(
        const SizedBox(
          width: 230,
          height: 100,
          child: Center(child: Icon(Icons.broken_image_outlined)),
        ),
        dark,
      );
    }

    final local = _isLocal(path);
    final cleanPath = path.replaceFirst('file://', '');
    final image = local
        ? Image.file(File(cleanPath), fit: BoxFit.contain)
        : CachedNetworkImage(imageUrl: path, fit: BoxFit.contain);

    final previewImage = local
        ? Image.file(
            File(cleanPath),
            width: 230,
            height: 230,
            fit: BoxFit.cover,
          )
        : CachedNetworkImage(
            imageUrl: path,
            width: 230,
            height: 230,
            fit: BoxFit.cover,
            placeholder: (_, __) => const SizedBox(
              width: 230,
              height: 230,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (_, __, ___) => const SizedBox(
              width: 230,
              height: 230,
              child: Center(child: Icon(Icons.broken_image_outlined)),
            ),
          );

    final preview = Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: previewImage,
        ),
        PositionedDirectional(
          top: 8,
          start: 8,
          child: _mediaTypeChip(Icons.photo_outlined, 'صورة', dark),
        ),
        if (m['isUploading'] == true)
          PositionedDirectional(
            bottom: 8,
            start: 8,
            child: _uploadChip(m, dark),
          ),
      ],
    );

    return GestureDetector(
      onTap: () async {
        if (!local && path.startsWith('http')) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MediaViewer(
                mediaUrl: path,
                mediaType: 'image',
              ),
            ),
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
        children: [
          preview,
          _mediaMeta(m, compact: true),
        ],
      ),
    );
  }

  Widget _buildVideo(String path) {
    final dark = Theme.of(context).brightness == Brightness.dark;
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
              child: _mediaTypeChip(Icons.play_circle_outline_rounded, 'فيديو', dark),
            ),
            if (widget.message['isUploading'] == true)
              PositionedDirectional(
                bottom: 8,
                start: 8,
                child: _uploadChip(widget.message, dark),
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
    final tc = dark ? Colors.white : const Color(0xFF111B21);

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
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.isMe
                      ? Colors.white.withOpacity(.14)
                      : (dark ? Colors.white.withOpacity(.08) : const Color(0xFFEAF5F3)),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  isPdf ? Icons.picture_as_pdf_outlined : isText ? Icons.article_outlined : isOffice ? Icons.description_outlined : Icons.insert_drive_file_outlined,
                  color: isPdf ? Colors.redAccent : tc,
                  size: 25,
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
      case 'cancelled':
        icon = Icons.call_end_rounded;
        statusLabel = incoming ? 'أُلغي الاتصال' : 'تم إلغاء الاتصال';
        break;
      case 'calling':
      case 'ringing':
        icon = incoming ? Icons.call_received_rounded : Icons.call_made_rounded;
        statusLabel = incoming ? 'مكالمة واردة' : 'جاري الاتصال';
        break;
      default:
        icon = incoming ? Icons.call_received_rounded : Icons.call_made_rounded;
        statusLabel = incoming ? 'مكالمة واردة' : 'مكالمة صادرة';
    }

    final title = 'مكالمة ${video ? 'فيديو' : 'صوتية'}';
    final tc = dark ? Colors.white : const Color(0xFF111B21);
    final statusColor = switch (status) {
      'missed' || 'rejected' => Colors.red,
      'busy' => Colors.orange,
      'cancelled' => Colors.grey,
      'ended' => AppColors.primary,
      _ => incoming ? Colors.green : AppColors.primary,
    };

    return _shell(
      Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _mediaTypeChip(
              video ? Icons.videocam_outlined : Icons.call_outlined,
              video ? 'مكالمة فيديو' : 'مكالمة صوتية',
              dark,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: statusColor, size: 22),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(color: tc, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 3),
                      Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: widget.isMe ? Colors.white.withOpacity(.12) : AppColors.primary.withOpacity(.10),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => widget.onCallAgain?.call(video ? 'video' : 'audio'),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(video ? Icons.videocam_rounded : Icons.call_rounded, color: tc, size: 19),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      dark,
    );
  }

  Widget _buildContact(Map<String, dynamic> m, bool dark) {
    final meta = m['metadata'] is Map ? Map<String, dynamic>.from(m['metadata'] as Map) : <String, dynamic>{};
    final name = meta['contactName']?.toString().trim().isNotEmpty == true ? meta['contactName'].toString() : 'جهة اتصال';
    final phone = meta['contactPhone']?.toString().trim() ?? '';
    final email = meta['contactEmail']?.toString().trim() ?? '';
    final tc = dark ? Colors.white : const Color(0xFF111B21);
    return _shell(
      Padding(
        padding: const EdgeInsets.all(11),
        child: SizedBox(
          width: 250,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _mediaTypeChip(Icons.person_outline_rounded, 'جهة اتصال', dark),
              const SizedBox(height: 8),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: widget.isMe ? Colors.white24 : AppColors.primary.withOpacity(.12),
                    child: Icon(Icons.person, color: widget.isMe ? Colors.white : AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: tc, fontWeight: FontWeight.w800)),
                        if (phone.isNotEmpty) Text(phone, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: tc.withOpacity(.75), fontSize: 12)),
                        if (email.isNotEmpty) Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: tc.withOpacity(.65), fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      dark,
    );
  }

  Widget _buildLocation(Map<String, dynamic> m, bool dark) {
    final lat = (m['locationLat'] as num?)?.toDouble();
    final lng = (m['locationLng'] as num?)?.toDouble();
    final address = (m['locationAddress']?.toString().trim().isNotEmpty == true)
        ? m['locationAddress'].toString().trim()
        : (m['text']?.toString().trim().isNotEmpty == true
            ? m['text'].toString().trim()
            : 'الموقع');
    final meta = m['metadata'] is Map
        ? Map<String, dynamic>.from(m['metadata'] as Map)
        : <String, dynamic>{};
    final street = meta['locationStreet']?.toString().trim() ?? '';
    final neighborhood = meta['locationNeighborhood']?.toString().trim() ?? '';
    final city = meta['locationCity']?.toString().trim() ?? '';
    final url = m['locationUrl']?.toString().trim() ?? '';
    final tc = widget.isMe
        ? Colors.white
        : (dark ? Colors.white : const Color(0xFF20312F));
    final secondary = widget.isMe
        ? Colors.white70
        : (dark ? Colors.white70 : const Color(0xFF647875));

    final details = <String>[];
    for (final value in [street, neighborhood, city]) {
      if (value.isEmpty || address.contains(value) || details.contains(value)) {
        continue;
      }
      details.add(value);
    }

    final hasCoordinates = lat != null && lng != null;
    final map = hasCoordinates
        ? SizedBox(
            width: 250,
            height: 155,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(lat, lng),
                initialZoom: 16,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.memo.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(lat, lng),
                      width: 42,
                      height: 50,
                      alignment: Alignment.bottomCenter,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 42,
                      ),
                    ),
                  ],
                ),
                const RichAttributionWidget(
                  attributions: [TextSourceAttribution('OpenStreetMap')],
                ),
              ],
            ),
          )
        : null;

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (map != null)
            Stack(
              children: [
                map,
                PositionedDirectional(
                  top: 8,
                  start: 8,
                  child: _mediaTypeChip(
                    Icons.location_on_rounded,
                    'موقع',
                    dark,
                  ),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 10, 11, 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: widget.isMe
                            ? Colors.white.withOpacity(.14)
                            : AppColors.primary.withOpacity(.11),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.location_on_rounded,
                        size: 18,
                        color: widget.isMe ? Colors.white : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        address,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tc,
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    details.join(' • '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: secondary,
                      fontSize: 10,
                      height: 1.3,
                    ),
                  ),
                ],
                if (hasCoordinates) ...[
                  const SizedBox(height: 6),
                  Text(
                    lat.toStringAsFixed(6) + ', ' + lng.toStringAsFixed(6),
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      color: secondary.withOpacity(.9),
                      fontSize: 9,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
                if (url.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.open_in_new_rounded,
                        size: 13,
                        color: widget.isMe ? Colors.white70 : AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'فتح الخريطة',
                        style: TextStyle(
                          color: widget.isMe ? Colors.white : AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return _shell(
      InkWell(
        onTap: url.isEmpty
            ? null
            : () async {
                final uri = Uri.tryParse(url);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
        borderRadius: BorderRadius.circular(15),
        child: card,
      ),
      dark,
    );
  }

  Widget _buildSystem(Map<String, dynamic> m) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Center(child: Text(m['text']?.toString() ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF49615E)))));

  void _options() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            if (widget.onReaction != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['👍', '❤️', '😂', '😮', '🙏']
                      .map((emoji) => IconButton(
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onReaction?.call(emoji);
                            },
                            icon: Text(emoji, style: const TextStyle(fontSize: 24)),
                          ))
                      .toList(),
                ),
              ),
            if ((widget.message['text']?.toString().trim() ?? '').isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('نسخ الرسالة'),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: widget.message['text'].toString()));
                  if (mounted) Navigator.pop(context);
                },
              ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('معلومات الرسالة'),
              onTap: () {
                Navigator.pop(context);
                _showMessageInfo();
              },
            ),
            if (widget.onReply != null)
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('رد'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onReply?.call();
                },
              ),
            if (widget.onEdit != null && widget.message['isDeleted'] != true && (widget.message['text']?.toString().trim() ?? '').isNotEmpty)
              ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('تعديل الرسالة'), onTap: () { Navigator.pop(context); widget.onEdit?.call(); }),
            if (widget.onStar != null)
              ListTile(leading: Icon(widget.message['isStarred'] == true ? Icons.star : Icons.star_border), title: Text(widget.message['isStarred'] == true ? 'إزالة من المفضلة' : 'حفظ في المفضلة'), onTap: () { Navigator.pop(context); widget.onStar?.call(); }),
            if (widget.onPin != null)
              ListTile(leading: Icon((widget.message['isPinned'] == true) ? Icons.push_pin : Icons.push_pin_outlined), title: Text(widget.message['isPinned'] == true ? 'إلغاء تثبيت الرسالة' : 'تثبيت الرسالة'), onTap: () { Navigator.pop(context); widget.onPin?.call(); }),
            if (widget.onForward != null)
              ListTile(
                leading: const Icon(Icons.forward_outlined),
                title: const Text('إعادة توجيه'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onForward?.call();
                },
              ),
            if (widget.onDeleteForMe != null)
              ListTile(leading: const Icon(Icons.delete_sweep_outlined), title: const Text('حذف لدي فقط'), onTap: () { Navigator.pop(context); widget.onDeleteForMe?.call(); }),
            if (widget.onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('حذف للجميع'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onDelete?.call();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _TextDocumentDialog extends StatelessWidget {
  final String title;
  final String content;
  const _TextDocumentDialog({required this.title, required this.content});
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(12),
    child: SizedBox(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * .82,
      child: Column(children: [
        AppBar(title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis), automaticallyImplyLeading: false,
          actions: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: SelectableText(content, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 14, height: 1.7)))),
      ]),
    ),
  );
}

class _DocumentWebViewDialog extends StatefulWidget {
  final String title;
  final String url;
  const _DocumentWebViewDialog({required this.title, required this.url});
  @override State<_DocumentWebViewDialog> createState() => _DocumentWebViewDialogState();
}

class _DocumentWebViewDialogState extends State<_DocumentWebViewDialog> {
  late final WebViewController _controller;
  @override
  void initState() {
    super.initState();
    final viewerUrl = 'https://docs.google.com/gview?embedded=1&url=${Uri.encodeComponent(widget.url)}';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(viewerUrl));
  }
  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(8),
    child: SizedBox(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * .9,
      child: Column(children: [
        AppBar(title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis), automaticallyImplyLeading: false,
          actions: [
            IconButton(onPressed: () async { final uri = Uri.tryParse(widget.url); if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication); }, icon: const Icon(Icons.open_in_new)),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ]),
        Expanded(child: WebViewWidget(controller: _controller)),
      ]),
    ),
  );
}

class _InlineVideoPreview extends StatefulWidget {
  const _InlineVideoPreview({
    required this.url,
    required this.isLocal,
    required this.onOpen,
  });

  final String url;
  final bool isLocal;
  final VoidCallback onOpen;

  @override
  State<_InlineVideoPreview> createState() => _InlineVideoPreviewState();
}

class _InlineVideoPreviewState extends State<_InlineVideoPreview> {
  VideoPlayerController? _controller;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final rawPath = widget.url.trim();
    final localPath = rawPath.replaceFirst('file://', '');
    try {
      final controller = widget.isLocal
          ? VideoPlayerController.file(File(localPath))
          : VideoPlayerController.networkUrl(Uri.parse(rawPath));

      _controller = controller;
      await controller.initialize();
      await controller.setLooping(false);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _loading = false);
    } catch (error) {
      await _controller?.dispose();
      _controller = null;
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const width = 230.0;
    const height = 160.0;

    if (_loading) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: const SizedBox(
          width: width,
          height: height,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    if (_error != null || _controller == null || !_controller!.value.isInitialized) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: width,
          height: height,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.video_file_outlined,
                size: 34,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 7),
              Text(
                'تعذر تحميل الفيديو',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _initialize();
                },
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _controller!;
    return GestureDetector(
      onTap: widget.onOpen,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ColoredBox(
                color: Colors.black,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio > 0
                        ? controller.value.aspectRatio
                        : 16 / 9,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final playing = value.isPlaying;
                  return AnimatedOpacity(
                    opacity: playing ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: IgnorePointer(
                      ignoring: playing,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black38,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoViewer extends StatefulWidget {
  final String url;
  final bool isLocal;
  const _VideoViewer({required this.url, required this.isLocal});
  @override State<_VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<_VideoViewer> {
  late final VideoPlayerController controller;
  @override void initState() {
    super.initState();
    final path = widget.url.replaceFirst('file://', '');
    controller = widget.isLocal ? VideoPlayerController.file(File(path)) : VideoPlayerController.networkUrl(Uri.parse(path));
    controller.initialize().then((_) { if (mounted) setState(() {}); });
  }
  @override void dispose() { controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    if (!controller.value.isInitialized) return const Dialog(backgroundColor: Colors.black, child: SizedBox(height: 240, child: Center(child: CircularProgressIndicator())));
    return Dialog(backgroundColor: Colors.black, insetPadding: const EdgeInsets.all(12), child: AspectRatio(aspectRatio: controller.value.aspectRatio, child: Stack(alignment: Alignment.center, children: [VideoPlayer(controller), IconButton(icon: Icon(controller.value.isPlaying ? Icons.pause_circle : Icons.play_circle, color: Colors.white, size: 52), onPressed: () => setState(() => controller.value.isPlaying ? controller.pause() : controller.play()))])));
  }
}

class JustAudioMessagePlayer extends StatefulWidget {
  final String url;
  final bool local;
  const JustAudioMessagePlayer({super.key, required this.url, this.local = false});
  @override State<JustAudioMessagePlayer> createState() => _JustAudioMessagePlayerState();
}

class _JustAudioMessagePlayerState extends State<JustAudioMessagePlayer> {
  final player = AudioPlayer();
  bool ready = false;
  @override void dispose() { player.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (context, snapshot) {
        final playing = snapshot.data?.playing ?? false;
        return IconButton(
          icon: Icon(playing ? Icons.pause_circle : Icons.play_circle),
          onPressed: () async {
            if (!ready) {
              if (widget.local) {
                await player.setFilePath(widget.url.replaceFirst('file://', ''));
              } else {
                await player.setUrl(widget.url);
              }
              ready = true;
            }
            if (playing) {
              await player.pause();
            } else {
              await player.play();
            }
          },
        );
      },
    );
  }
}



