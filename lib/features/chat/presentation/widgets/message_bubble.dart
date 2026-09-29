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
import 'package:memochat/core/services/chat_media_transfer_service.dart';
import 'package:memochat/core/constants/app_colors.dart';
import 'package:memochat/core/services/medical_document_service.dart';
import 'package:memochat/presentation/screens/chat/widgets/audio_waveform_bubble.dart';

class MessageBubble extends StatefulWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;
  final Function(String)? onReaction;
  final VoidCallback? onPin;
  final VoidCallback? onDeleteForMe;
  final VoidCallback? onEdit;
  final Function(String)? onCallAgain;
  final bool isFirstInChat;
  final VoidCallback? onReplyPreviewTap;

  const MessageBubble({super.key, required this.message, required this.isMe, this.onReply, this.onDelete, this.onReaction, this.onPin, this.onDeleteForMe, this.onEdit, this.onCallAgain, this.isFirstInChat = false, this.onReplyPreviewTap});

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _isLocal(String path) => widget.message['isLocal'] == true || widget.message['isUploading'] == true || path.startsWith('file://') || (path.isNotEmpty && !path.startsWith('http') && File(path).existsSync());

  String _formatMessageTime(dynamic value) {
    if (value == null) return 'غير متوفر';
    DateTime? date;
    if (value is Timestamp) date = value.toDate();
    if (value is DateTime) date = value;
    if (value is String) date = DateTime.tryParse(value);
    if (date == null) return 'غير متوفر';
    final local = date.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final mo = local.month.toString().padLeft(2, '0');
    return '$dd/$mo/${local.year} $hh:$mm';
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
      onLongPress: _options,
      child: Container(
          decoration: BoxDecoration(
              color: widget.isMe
                  ? AppColors.primary
                  : (dark ? const Color(0xFF1A2540) : const Color(0xFFF9FCFB)),
              borderRadius: widget.isFirstInChat
                  ? BorderRadius.circular(18)
                  : BorderRadius.circular(14),
              border: !widget.isMe && !dark
                  ? Border.all(color: const Color(0xFFC8DEDA), width: .8)
                  : null,
              boxShadow: !widget.isMe && !dark
                  ? const [
                      BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 4,
                          offset: Offset(0, 1))
                    ]
                  : null),
          child: child));

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
            _shell(AudioWaveformBubble(audioUrl: url, isMe: widget.isMe, isLocal: _isLocal(url)), dark),
          ],
        );
      case 'file':
        return _withStatus(_buildFile(m, dark));
      case 'call':
        return _withStatus(_buildCall(m, dark));
      case 'location':
        return _withStatus(_buildLocation(m, dark));
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
            Flexible(child: Text(m['text']?.toString() ?? '', style: TextStyle(color: widget.isMe ? Colors.white : (dark ? Colors.white : const Color(0xFF20312F)), fontSize: 14))),
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
      case 'image': return '📷 صورة';
      case 'video': return '🎬 فيديو';
      case 'audio': return '🎤 رسالة صوتية';
      case 'file': return '📎 ملف';
      case 'location': return '📍 موقع';
      case 'call': return '📞 مكالمة';
      default: return 'مرفق';
    }
  }


  String _timeLabel(dynamic value) { final DateTime? date = value is Timestamp ? value.toDate() : value is DateTime ? value : value is String ? DateTime.tryParse(value) : null; if (date == null) return ''; final h = date.hour.toString().padLeft(2, '0'); final min = date.minute.toString().padLeft(2, '0'); return '$h:$min'; }

  Widget _status(Map<String, dynamic> m) {
    if (m['isSending'] == true) return const Icon(Icons.schedule, size: 14, color: Colors.grey);
    if (m['isRead'] == true) return const Icon(Icons.done_all, size: 15, color: AppColors.primary);
    if (m['isDelivered'] == true) return const Icon(Icons.done_all, size: 15, color: Colors.grey);
    return const Icon(Icons.check, size: 15, color: Colors.grey);
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

  Widget _buildImage(String path) {
    if (path.isEmpty) return const SizedBox(width: 230, height: 100, child: Center(child: Text('تعذر تحميل الصورة')));
    final local = _isLocal(path);
    final cleanPath = path.replaceFirst('file://', '');
    final image = local ? Image.file(File(cleanPath), fit: BoxFit.contain) : CachedNetworkImage(imageUrl: path, fit: BoxFit.contain);
    return GestureDetector(onTap: () => showDialog<void>(context: context, barrierColor: Colors.black87, builder: (_) => Dialog(backgroundColor: Colors.transparent, child: InteractiveViewer(child: image))), child: ClipRRect(borderRadius: BorderRadius.circular(14), child: local ? Image.file(File(cleanPath), width: 230, height: 230, fit: BoxFit.cover) : CachedNetworkImage(imageUrl: path, width: 230, height: 230, fit: BoxFit.cover, placeholder: (_, __) => const SizedBox(width: 230, height: 230, child: Center(child: CircularProgressIndicator(strokeWidth: 2))), errorWidget: (_, __, ___) => const SizedBox(width: 230, height: 230, child: Center(child: Icon(Icons.broken_image))))));
  }

  Widget _buildVideo(String path) {
    if (path.isEmpty) return const SizedBox(width: 230, height: 100, child: Center(child: Text('تعذر تحميل الفيديو')));
    return GestureDetector(onTap: () => showDialog<void>(context: context, builder: (_) => _VideoViewer(url: path, isLocal: _isLocal(path))), child: Container(width: 230, height: 160, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(14)), child: const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 50))));
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

    Future<File?> _downloadRemote() async {
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

    Future<void> _chooseMedicalService(String formType) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final isLab = formType == 'labs';
      final choice = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(16), child: Text(
            isLab ? 'كيف تريد تنفيذ الفحوصات؟' : 'كيف تريد صرف الوصفة؟',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          ListTile(leading: const Icon(Icons.storefront_outlined), title: Text(isLab ? 'اختيار مختبر من منصة صحتك' : 'اختيار صيدلية من منصة صحتك'), onTap: () => Navigator.pop(ctx, 'facility')),
          ListTile(leading: const Icon(Icons.home_work_outlined), title: Text(isLab ? 'طلب سحب العينة من المنزل' : 'طلب توصيل الدواء إلى المنزل'), onTap: () => Navigator.pop(ctx, 'home')),
          ListTile(leading: const Icon(Icons.directions_walk_outlined), title: Text(isLab ? 'سأذهب بنفسي إلى المختبر' : 'سأستلم الدواء من الصيدلية'), onTap: () => Navigator.pop(ctx, 'self')),
        ])),
      );
      if (choice == null) return;
      String? facilityId;
      String? facilityName;
      if (choice == 'facility') {
        final names = <Map<String,String>>[];
        for (final collection in isLab ? ['labs','laboratories'] : ['pharmacies']) {
          try {
            final s = await FirebaseFirestore.instance.collection(collection).limit(30).get();
            for (final d in s.docs) {
              final data = d.data();
              names.add({'id': d.id, 'name': (data['name'] ?? data['title'] ?? 'منشأة صحية').toString()});
            }
          } catch (_) {}
          if (names.isNotEmpty) break;
        }
        if (!mounted) return;
        final selected = await showModalBottomSheet<Map<String,String>>(
          context: context, showDragHandle: true,
          builder: (ctx) => SafeArea(child: SizedBox(height: 420, child:
            names.isEmpty ? const Center(child: Text('لا توجد منشآت متاحة حالياً')) :
            ListView(children: [for (final n in names)
              ListTile(leading: Icon(isLab ? Icons.biotech : Icons.local_pharmacy), title: Text(n['name']!), onTap: () => Navigator.pop(ctx, n))]
          ))),
        );
        if (selected == null) return;
        facilityId = selected['id'];
        facilityName = selected['name'];
      }
      final docs = await FirebaseFirestore.instance.collection('medical_documents')
          .where('fileName', isEqualTo: name).limit(1).get();
      final documentId = docs.docs.isNotEmpty ? docs.docs.first.id : '';
      if (documentId.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر العثور على المستند الطبي.')));
        return;
      }
      await FirebaseFirestore.instance.collection('medical_requests').add({
        'documentId': documentId,
        'type': isLab ? 'lab' : 'pharmacy',
        'patientId': uid,
        'doctorId': docs.docs.first.data()['doctorId'],
        'mode': choice,
        'facilityId': facilityId,
        'facilityName': facilityName,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isLab ? 'تم إرسال طلب الفحوصات.' : 'تم إرسال الوصفة إلى خدمة الصيدلية.')),
      );
    }


    Future<void> _sendToAnotherChat(File file) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final snap = await FirebaseFirestore.instance.collection('chats').where('participants', arrayContains: uid).limit(50).get();
      if (!mounted) return;
      final selected = await showModalBottomSheet<String>(
        context: context, showDragHandle: true,
        builder: (ctx) => SafeArea(child: SizedBox(height: 420, child: ListView(
          children: snap.docs.where((d) => d.id != m['chatId']).map((d) {
            final data = d.data(); final parts = List<String>.from(data['participants'] ?? const []);
            final other = parts.firstWhere((x) => x != uid, orElse: () => '');
            final details = data['participantDetails'] is Map ? Map<String,dynamic>.from(data['participantDetails']) : <String,dynamic>{};
            final otherData = details[other] is Map ? Map<String,dynamic>.from(details[other]) : <String,dynamic>{};
            return ListTile(leading: const Icon(Icons.chat_bubble_outline), title: Text((otherData['name'] ?? 'محادثة').toString()), onTap: () => Navigator.pop(ctx, d.id));
          }).toList(),
        ))),
      );
      if (selected == null) return;
      await ChatMediaTransferService.instance.enqueue(
        chatId: selected, sourceFile: file, type: 'file', folder: 'documents',
        preview: '📄 $name', fileName: name, fileSize: m['fileSize']?.toString(), mimeType: mime,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تجهيز المستند للإرسال إلى الدردشة المحددة.')));
    }

    Future<void> _documentActions() async {
      if (url.isEmpty) return;
      final action = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (name.toLowerCase().contains('_rx.pdf') || name.toLowerCase().contains('_labs.pdf'))
            ListTile(
              leading: Icon(name.toLowerCase().contains('_labs.pdf') ? Icons.biotech_outlined : Icons.local_pharmacy_outlined),
              title: Text(name.toLowerCase().contains('_labs.pdf') ? 'تنفيذ طلب الفحوصات' : 'تنفيذ الوصفة الطبية'),
              onTap: () => Navigator.pop(ctx, 'service'),
            ),
          ListTile(leading: const Icon(Icons.visibility_outlined), title: const Text('فتح المستند'), onTap: () => Navigator.pop(ctx, 'open')),
          ListTile(leading: const Icon(Icons.share_outlined), title: const Text('مشاركة / إرسال خارج التطبيق'), onTap: () => Navigator.pop(ctx, 'share')),
          ListTile(leading: const Icon(Icons.save_alt_outlined), title: const Text('حفظ في المكتبة'), onTap: () => Navigator.pop(ctx, 'library')),
          ListTile(leading: const Icon(Icons.download_outlined), title: const Text('حفظ نسخة على الهاتف'), onTap: () => Navigator.pop(ctx, 'download')),
          ListTile(leading: const Icon(Icons.send_outlined), title: const Text('إرسال إلى دردشة أخرى'), onTap: () => Navigator.pop(ctx, 'chat')),
        ])),
      );
      if (action == null) return;
      final file = await _downloadRemote();
      if (file == null) { _showFileError(); return; }
      if (action == 'service') {
        await _chooseMedicalService(name.toLowerCase().contains('_labs.pdf') ? 'labs' : 'rx');
      } else if (action == 'open') {
        if (isPdf || isOffice) {
          if (mounted) await showDialog<void>(context: context, builder: (_) => _DocumentWebViewDialog(title: name, url: url));
        } else if (isText) {
          final text = await file.readAsString();
          if (mounted) await showDialog<void>(context: context, builder: (_) => _TextDocumentDialog(title: name, content: text));
        }
      } else if (action == 'share' || action == 'download') {
        await MedicalDocumentServiceCompat.share(file, download: action == 'download');
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
        await _documentActions();
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
              Icon(
                isPdf ? Icons.picture_as_pdf_outlined : isText ? Icons.article_outlined : isOffice ? Icons.description_outlined : Icons.insert_drive_file_outlined,
                color: isPdf ? Colors.red : tc,
                size: 30,
              ),
              const SizedBox(width: 10),
              Flexible(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: tc, fontWeight: FontWeight.w700)),
                  if ((m['fileSize']?.toString() ?? '').isNotEmpty)
                    Text(m['fileSize'].toString(), style: TextStyle(color: tc.withOpacity(.65), fontSize: 10)),
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
    final meta = m['metadata'] is Map ? Map<String, dynamic>.from(m['metadata']) : <String, dynamic>{};
    final status = (meta['status'] ?? '').toString();
    final video = meta['isVideo'] == true || meta['callType']?.toString() == 'video';
    final duration = (meta['duration'] ?? '').toString();
    final missed = status == 'missed' || status == 'rejected' || status == 'busy';
    final incoming = !missed && !widget.isMe;
    final icon = missed ? Icons.call_missed : incoming ? Icons.call_received : Icons.call_made;
    final title = missed ? 'مكالمة ${video ? 'فيديو' : 'صوتية'} فائتة' : incoming ? 'مكالمة ${video ? 'فيديو' : 'صوتية'} واردة' : 'مكالمة ${video ? 'فيديو' : 'صوتية'} صادرة';
    final tc = widget.isMe ? Colors.white : (dark ? Colors.white : const Color(0xFF20312F));
    final ic = missed ? Colors.red : incoming ? Colors.green : Colors.blue;
    return _shell(Padding(padding: const EdgeInsets.all(10), child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: ic.withOpacity(.15), shape: BoxShape.circle), child: Icon(icon, color: ic, size: 24)), const SizedBox(width: 12), Flexible(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: tc, fontWeight: FontWeight.bold, fontSize: 13)), if (duration.isNotEmpty) ...[const SizedBox(height: 3), Text(duration, style: TextStyle(color: tc.withOpacity(.7), fontSize: 11))]])), const SizedBox(width: 12), InkWell(borderRadius: BorderRadius.circular(20), onTap: () => widget.onCallAgain?.call(video ? 'video' : 'audio'), child: Padding(padding: const EdgeInsets.all(6), child: Icon(video ? Icons.videocam : Icons.call, color: tc, size: 20)))])), dark);
  }

  Widget _buildLocation(Map<String, dynamic> m, bool dark) {
    final lat = (m['locationLat'] as num?)?.toDouble();
    final lng = (m['locationLng'] as num?)?.toDouble();
    final address = (m['locationAddress']?.toString().trim().isNotEmpty == true)
        ? m['locationAddress'].toString()
        : (m['text']?.toString() ?? 'الموقع');
    final meta = m['metadata'] is Map ? Map<String, dynamic>.from(m['metadata'] as Map) : <String, dynamic>{};
    final street = meta['locationStreet']?.toString() ?? '';
    final neighborhood = meta['locationNeighborhood']?.toString() ?? '';
    final city = meta['locationCity']?.toString() ?? '';
    final url = m['locationUrl']?.toString() ?? '';
    final tc = widget.isMe ? Colors.white : (dark ? Colors.white : const Color(0xFF20312F));

    final details = <String>[];
    for (final value in [street, neighborhood, city]) {
      final clean = value.trim();
      if (clean.isEmpty) continue;
      if (address.contains(clean)) continue;
      if (details.any((item) => item == clean)) continue;
      details.add(clean);
    }

    final map = lat == null || lng == null
        ? const SizedBox.shrink()
        : SizedBox(
            width: 250,
            height: 155,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(lat, lng),
                initialZoom: 16,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.sehatak.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(lat, lng),
                      width: 42,
                      height: 50,
                      alignment: Alignment.bottomCenter,
                      child: const Icon(Icons.location_pin, color: Colors.red, size: 42),
                    ),
                  ],
                ),
                const RichAttributionWidget(
                  attributions: [TextSourceAttribution('OpenStreetMap')],
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
        borderRadius: BorderRadius.circular(14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (lat != null && lng != null) map,
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, color: Colors.redAccent, size: 22),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('الموقع المرسل', style: TextStyle(color: tc, fontWeight: FontWeight.w800, fontSize: 12)),
                          const SizedBox(height: 3),
                          Text(address, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: tc, fontSize: 12)),
                          if (details.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(details.join(' • '), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: tc.withOpacity(.75), fontSize: 10)),
                          ],
                          if (lat != null && lng != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                              textDirection: TextDirection.ltr,
                              style: TextStyle(color: tc.withOpacity(.65), fontSize: 9),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
            if (widget.onPin != null)
              ListTile(leading: Icon((widget.message['isPinned'] == true) ? Icons.push_pin : Icons.push_pin_outlined), title: Text(widget.message['isPinned'] == true ? 'إلغاء تثبيت الرسالة' : 'تثبيت الرسالة'), onTap: () { Navigator.pop(context); widget.onPin?.call(); }),
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
              if (widget.local) await player.setFilePath(widget.url.replaceFirst('file://', ''));
              else await player.setUrl(widget.url);
              ready = true;
            }
            if (playing) { await player.pause(); } else { await player.play(); }
          },
        );
      },
    );
  }
}

class MedicalDocumentServiceCompat {
  static Future<void> share(File file, {bool download = false}) async {
    await Share.shareXFiles([XFile(file.path)], text: download ? 'نسخة محفوظة من مستند صحتك' : 'مستند من منصة صحتك');
  }
}
