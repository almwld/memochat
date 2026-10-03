import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:memochat/features/chat/services/chat_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:record/record.dart';
import 'package:memochat/core/constants/app_colors.dart';
import 'package:memochat/features/chat/services/chat_media_transfer_service.dart';
import 'package:memochat/features/chat/services/reliable_message_service.dart';
import 'package:memochat/features/chat/services/toast_service.dart';
import 'package:memochat/features/games/presentation/games_screen.dart';

class ChatInputBar extends StatefulWidget {
  final String chatId;
  /// Explicit reply target supplied by ChatRoomScreen. Keeping this in the
  /// input widget prevents the reply context from being lost between the UI
  /// and the actual Firestore write.
  final String? replyToId;
  final Function(String, Timestamp) onSendMessage;
  final Function(String)? onSendImage;
  final Function(Map<String, dynamic>)? onLocalMedia;
  final VoidCallback? onShareLocation;
  final Function(bool)? onTyping;

  const ChatInputBar({
    super.key,
    required this.chatId,
    this.replyToId,
    required this.onSendMessage,
    this.onSendImage,
    this.onLocalMedia,
    this.onShareLocation,
    this.onTyping,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _picker = ImagePicker();
  final _recorder = AudioRecorder();
  Timer? _timer;
  Timer? _typingTimer;
  Duration _duration = Duration.zero;
  String? _recordPath;
  bool _recording = false;
  bool _paused = false;
  bool _sending = false;
  bool _attachments = false;
  bool _loadingRecent = false;
  List<AssetEntity> _recentAssets = const [];

  bool get _hasText => _controller.text.trim().isNotEmpty;
  bool get _hasRecording => _recordPath != null;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
    if (_controller.text.trim().isNotEmpty) {
      widget.onTyping?.call(true);
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () => widget.onTyping?.call(false));
    } else {
      _typingTimer?.cancel();
      widget.onTyping?.call(false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _typingTimer?.cancel();
    widget.onTyping?.call(false);
    _controller.dispose();
    _focus.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _toggleAttachments() async {
    if (_sending) return;
    if (_attachments) {
      setState(() => _attachments = false);
      return;
    }

    // Close the IME first, then reveal the attachment panel in the space
    // previously occupied by the keyboard. This avoids the panel jumping
    // above the keyboard while the keyboard is still animating away.
    _focus.unfocus(disposition: UnfocusDisposition.scope);
    FocusScope.of(context).unfocus(disposition: UnfocusDisposition.scope);
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    setState(() => _attachments = true);
    await _loadRecentGallery();
  }

  Future<void> _loadRecentGallery() async {
    if (_loadingRecent) return;
    setState(() => _loadingRecent = true);
    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth) {
        if (mounted) {
          ToastService.showError('اسمح بالوصول إلى الصور لعرض الملفات الحديثة.');
        }
        return;
      }
      final paths = await PhotoManager.getAssetPathList(
        onlyAll: true,
        type: RequestType.common,
      );
      if (paths.isEmpty) return;
      final assets = await paths.first.getAssetListPaged(page: 0, size: 24);
      if (mounted) setState(() => _recentAssets = assets);
    } catch (e) {
      debugPrint('recent gallery load: $e');
    } finally {
      if (mounted) setState(() => _loadingRecent = false);
    }
  }

  Future<void> _sendRecentAsset(AssetEntity asset) async {
    final file = await asset.file;
    if (file == null) {
      ToastService.showError('تعذر الوصول إلى هذا الملف.');
      return;
    }
    final isVideo = asset.type == AssetType.video;
    await _sendMedia(
      file,
      type: isVideo ? 'video' : 'image',
      folder: isVideo ? 'videos' : 'images',
      preview: isVideo ? '🎬 فيديو' : '📷 صورة',
      name: file.path.split(Platform.pathSeparator).last,
      size: _formatBytes(await file.length()),
      mime: isVideo ? 'video/mp4' : _imageMime(file.path),
    );
  }

  Future<void> _pickContact() async {
    if (_sending) return;
    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!granted || !mounted) {
      ToastService.showError('لم يتم السماح بالوصول إلى جهات الاتصال.');
      return;
    }
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    if (!mounted || contacts.isEmpty) {
      ToastService.showError('لا توجد جهات اتصال متاحة.');
      return;
    }
    final selected = await showModalBottomSheet<Contact>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * .7,
          child: ListView.builder(
            itemCount: contacts.length,
            itemBuilder: (_, index) {
              final c = contacts[index];
              final phone = c.phones.isNotEmpty ? c.phones.first.number : '';
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(c.displayName.isEmpty ? 'جهة اتصال' : c.displayName),
                subtitle: Text(phone.isEmpty ? 'بدون رقم هاتف' : phone),
                onTap: () => Navigator.pop(ctx, c),
              );
            },
          ),
        ),
      ),
    );
    if (selected == null) return;
    final name = selected.displayName.trim().isEmpty ? 'جهة اتصال' : selected.displayName.trim();
    final phone = selected.phones.isNotEmpty ? selected.phones.first.number.trim() : '';
    final email = selected.emails.isNotEmpty ? selected.emails.first.address.trim() : '';
    try {
      await ChatService().sendMessage(
        chatId: widget.chatId,
        text: name,
        metadata: {'kind': 'contact', 'contactName': name, 'contactPhone': phone, 'contactEmail': email},
        replyToId: widget.replyToId,
      );
      if (mounted) setState(() => _attachments = false);
    } catch (e) {
      if (mounted) ToastService.showError('تعذر إرسال جهة الاتصال.');
      debugPrint('contact send: $e');
    }
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending || _recording || _hasRecording) return;
    setState(() => _sending = true);
    final clientTimestamp = Timestamp.now();
    try {
      widget.onSendMessage(text, clientTimestamp);
      _controller.clear();
      await ReliableMessageService.sendText(
        chatId: widget.chatId,
        text: text,
        replyToId: widget.replyToId,
        clientTimestamp: clientTimestamp,
      );
    } catch (e) {
      debugPrint('chat text send: $e');
      ToastService.showError('تعذر إرسال الرسالة. تحقق من الاتصال.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _enqueueMedia(
    File file, {
    required String type,
    required String folder,
    required String preview,
    String? name,
    String? size,
    String? mime,
    String? audioDuration,
  }) async {
    final id = await ChatMediaTransferService.instance.enqueue(
      chatId: widget.chatId,
      sourceFile: file,
      type: type,
      folder: folder,
      preview: preview,
      fileName: name,
      fileSize: size,
      mimeType: mime,
      audioDuration: audioDuration,
    );
    final job = await ChatMediaTransferService.instance.getById(id);
    final localPath = job?['local_path']?.toString() ?? file.path;
    final status = job?['status']?.toString() ?? 'queued';
    widget.onLocalMedia?.call({
      'id': id,
      'chatId': widget.chatId,
      'senderId': 'local',
      'senderName': 'مستخدم',
      'type': type,
      'text': preview,
      'imageUrl': type == 'image' ? localPath : null,
      'videoUrl': type == 'video' ? localPath : null,
      'audioUrl': type == 'audio' ? localPath : null,
      'fileUrl': type == 'file' ? localPath : null,
      'fileName': name ?? pBasename(localPath),
      'fileSize': size,
      'fileMimeType': mime,
      'audioDuration': audioDuration,
      'isLocal': true,
      'isSending': true,
      'isUploading': status == 'uploading' || status == 'queued' || status == 'retry',
      'hasError': status == 'retry',
      'uploadStatus': status == 'retry' ? 'failed' : status == 'queued' ? 'pending' : 'uploading',
      'uploadProgress': (job?['progress'] as num?)?.toDouble() ?? 0.0,
      'outboxId': id,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  String pBasename(String path) => path.split(Platform.pathSeparator).last;

  String _imageMime(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }

  Future<void> _sendMedia(
    File file, {
    required String type,
    required String folder,
    required String preview,
    String? name,
    String? size,
    String? mime,
  }) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _attachments = false;
    });
    try {
      await _enqueueMedia(
        file,
        type: type,
        folder: folder,
        preview: preview,
        name: name,
        size: size,
        mime: mime,
      );
    } catch (e) {
      debugPrint('media enqueue: $e');
      ToastService.showError('تعذر تجهيز الوسائط للإرسال.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<File> _editImageFile(File source) async {
    final data = await source.readAsBytes();
    if (!mounted) return source;
    final edited = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ImageEditor(image: data)),
    );
    if (edited is! Uint8List || edited.isEmpty) return source;
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/edited_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final output = File(path);
    await output.writeAsBytes(edited, flush: true);
    return output;
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.gallery) {
      final xs = await _picker.pickMultiImage(imageQuality: 90);
      for (final x in xs) {
        final edited = await _editImageFile(File(x.path));
        await _sendMedia(edited, type: 'image', folder: 'images', preview: '📷 صورة');
      }
      return;
    }
    final x = await _picker.pickImage(source: source, imageQuality: 90);
    if (x != null) {
      final edited = await _editImageFile(File(x.path));
      await _sendMedia(edited, type: 'image', folder: 'images', preview: '📷 صورة');
    }
  }

  Future<void> _pickVideo() async {
    final x = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 10),
    );
    if (x != null) {
      await _sendMedia(
        File(x.path),
        type: 'video',
        folder: 'videos',
        preview: '🎬 فيديو',
      );
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    final picked = result?.files.single;
    if (picked?.path == null) return;
    final size = _formatBytes(picked!.size);
    final ext = (picked.extension ?? '').toLowerCase();
    final isAudio = {'mp3','m4a','aac','wav','ogg','oga','opus','amr','flac','3gp','webm'}.contains(ext);
    if (!mounted) return;
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAudio ? 'معاينة الملف الصوتي' : 'معاينة الملف'),
        content: ListTile(
          leading: Icon(isAudio ? Icons.audiotrack : Icons.insert_drive_file_outlined),
          title: Text(picked.name, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(size),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إرسال')),
        ],
      ),
    );
    if (send != true) return;
    if (isAudio) {
      await _sendMedia(
        File(picked.path!),
        type: 'audio',
        folder: 'audio',
        preview: '🎤 ملف صوتي',
        name: picked.name,
        size: size,
        mime: _guessAudioMime(ext),
      );
    } else {
      await _sendMedia(
        File(picked.path!),
        type: 'file',
        folder: 'files',
        preview: '📎 ${picked.name}',
        name: picked.name,
        size: size,
        mime: _guessMime(ext),
      );
    }
  }

  String _guessAudioMime(String extension) {
    switch (extension) {
      case 'mp3': return 'audio/mpeg';
      case 'm4a': return 'audio/mp4';
      case 'aac': return 'audio/aac';
      case 'wav': return 'audio/wav';
      case 'ogg':
      case 'oga': return 'audio/ogg';
      case 'opus': return 'audio/opus';
      case 'amr': return 'audio/amr';
      case 'flac': return 'audio/flac';
      case '3gp': return 'audio/3gpp';
      case 'webm': return 'audio/webm';
      default: return 'audio/mpeg';
    }
  }

  String _guessMime(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf': return 'application/pdf';
      case 'doc': return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls': return 'application/vnd.ms-excel';
      case 'xlsx': return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt': return 'application/vnd.ms-powerpoint';
      case 'pptx': return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'zip': return 'application/zip';
      case 'txt': return 'text/plain';
      default: return 'application/octet-stream';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
  }

  Future<void> _startRecording() async {
    if (_sending || _recording || _hasRecording || _hasText) return;
    if (!await _recorder.hasPermission()) {
      ToastService.showError('يلزم السماح بالوصول إلى الميكروفون.');
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/memochat_chat_${DateTime.now().millisecondsSinceEpoch}.m4a';
    try {
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      _duration = Duration.zero;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _recording && !_paused) {
          setState(() => _duration += const Duration(seconds: 1));
        }
      });
      setState(() {
        _recording = true;
        _paused = false;
        _recordPath = path;
      });
    } catch (e) {
      debugPrint('record start: $e');
      ToastService.showError('تعذر بدء التسجيل الصوتي.');
    }
  }

  Future<void> _stopRecording() async {
    if (!_recording) return;
    _timer?.cancel();
    try {
      await _recorder.stop();
    } catch (e) {
      debugPrint('record stop: $e');
    }
    if (mounted) setState(() { _recording = false; _paused = false; });
  }

  Future<void> _togglePause() async {
    if (!_recording) return;
    try {
      if (_paused) {
        await _recorder.resume();
      } else {
        await _recorder.pause();
      }
      if (mounted) setState(() => _paused = !_paused);
    } catch (e) {
      debugPrint('record pause/resume: $e');
    }
  }

  Future<void> _deleteRecording() async {
    _timer?.cancel();
    try { await _recorder.stop(); } catch (_) {}
    final path = _recordPath;
    _recordPath = null;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    if (mounted) {
      setState(() {
        _recording = false;
        _paused = false;
        _duration = Duration.zero;
      });
    }
  }

  Future<void> _sendRecording() async {
    if (_sending || _recordPath == null) return;
    if (_recording) await _stopRecording();
    final path = _recordPath;
    if (path == null) return;
    final file = File(path);
    if (!await file.exists() || await file.length() < 1000) {
      await _deleteRecording();
      ToastService.showError('التسجيل قصير جدًا.');
      return;
    }
    setState(() => _sending = true);
    try {
      await _enqueueMedia(
        file,
        type: 'audio',
        folder: 'audio',
        preview: '🎤 رسالة صوتية',
        name: file.path.split(Platform.pathSeparator).last,
        mime: 'audio/mp4',
        audioDuration: _duration.inSeconds.toString(),
      );
      _recordPath = null;
      _duration = Duration.zero;
    } catch (e) {
      debugPrint('audio enqueue: $e');
      ToastService.showError('تعذر تجهيز التسجيل للإرسال.');
    } finally {
      try { if (await file.exists()) await file.delete(); } catch (_) {}
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (_recording || _hasRecording) return _voiceBar(dark);

    final fieldColor = dark ? const Color(0xFF202C33) : const Color(0xFFFFFFFF);
    final barColor = dark ? const Color(0xFF111B21) : const Color(0xFFF0F2F5);
    final iconColor = dark ? const Color(0xFF8696A0) : const Color(0xFF54656F);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: barColor,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 46, maxHeight: 132),
                      decoration: BoxDecoration(
                        color: fieldColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(
                            tooltip: 'ملصقات ورموز',
                            onPressed: _sending ? null : () {},
                            icon: Icon(Icons.emoji_emotions_outlined, color: iconColor),
                            splashRadius: 21,
                          ),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focus,
                              minLines: 1,
                              maxLines: 5,
                              textDirection: TextDirection.rtl,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              style: TextStyle(
                                color: dark ? Colors.white : const Color(0xFF111B21),
                                fontSize: 16,
                                height: 1.25,
                              ),
                              decoration: InputDecoration(
                                hintText: 'اكتب رسالة...',
                                hintStyle: TextStyle(color: iconColor, fontSize: 15),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'الألعاب',
                            onPressed: _sending ? null : () => showGamesSheet(context, chatId: widget.chatId),
                            icon: Icon(Icons.sports_esports_outlined, color: iconColor),
                            splashRadius: 21,
                          ),
                          IconButton(
                            tooltip: 'إرفاق',
                            onPressed: _sending ? null : _toggleAttachments,
                            icon: Icon(Icons.attach_file_rounded, color: iconColor),
                            splashRadius: 21,
                          ),
                          if (!_hasText)
                            IconButton(
                              tooltip: 'الكاميرا',
                              onPressed: _sending ? null : () => _pickImage(ImageSource.camera),
                              icon: Icon(Icons.camera_alt_outlined, color: iconColor),
                              splashRadius: 21,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Semantics(
                    button: true,
                    label: _hasText ? 'إرسال' : 'تسجيل صوتي',
                    child: GestureDetector(
                      onTap: _sending ? null : (_hasText ? _sendText : _startRecording),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00A884),
                          shape: BoxShape.circle,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(scale: animation, child: child),
                          child: Icon(
                            _hasText ? Icons.send_rounded : Icons.mic_rounded,
                            key: ValueKey(_hasText),
                            color: Colors.white,
                            size: 23,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          reverseDuration: const Duration(milliseconds: 190),
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            axisAlignment: -1,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          ),
          child: _attachments
              ? _mediaMenu(dark)
              : const SizedBox.shrink(key: ValueKey('closed')),
        ),
      ],
    );
  }

  Widget _voiceBar(bool dark) => Material(
        color: Colors.transparent,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
              children: [
                IconButton(
                  onPressed: _sending ? null : _deleteRecording,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
                IconButton(
                  onPressed: _sending || !_recording ? null : _togglePause,
                  icon: Icon(_paused ? Icons.play_arrow : Icons.pause, color: AppColors.primary),
                ),
                Expanded(
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: dark ? const Color(0xFF26344D) : const Color(0xFFF1F4F5),
                      borderRadius: BorderRadius.circular(23),
                    ),
                    child: Row(
                      children: [
                        Icon(_recording ? Icons.mic : Icons.mic_none,
                            color: _recording ? Colors.red : AppColors.primary),
                        const SizedBox(width: 8),
                        Text('${_duration.inMinutes.toString().padLeft(2, '0')}:${(_duration.inSeconds % 60).toString().padLeft(2, '0')}'),
                        const SizedBox(width: 10),
                        const Expanded(child: LinearProgressIndicator(minHeight: 3)),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _sending ? null : (_recording ? _stopRecording : _sendRecording),
                  icon: Icon(
                    _recording ? Icons.stop_circle_outlined : Icons.send_rounded,
                    color: AppColors.primary,
                    size: 29,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _mediaMenu(bool dark) => GestureDetector(
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 180 && mounted) {
            setState(() => _attachments = false);
          }
        },
        child: Material(
        key: const ValueKey('attachments'),
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 2),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF121A29) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.10), blurRadius: 16, offset: const Offset(0, -4))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 34, height: 4, decoration: BoxDecoration(color: dark ? Colors.white24 : Colors.black12, borderRadius: BorderRadius.circular(3))),
              const SizedBox(height: 8),
              if (_loadingRecent)
                const SizedBox(height: 74, child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))))
              else if (_recentAssets.isNotEmpty)
                _recentGallery(dark)
              else
                const SizedBox(height: 6),
              const SizedBox(height: 8),
              _mediaItemPlaceholder,
            ],
          ),
        ),
      ),
      );

  Widget get _mediaItemPlaceholder => Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _mediaItem(Icons.camera_alt, 'كاميرا', () => _pickImage(ImageSource.camera)),
          _mediaItem(Icons.photo_library_outlined, 'المعرض', () => _pickImage(ImageSource.gallery)),
          _mediaItem(Icons.video_library, 'فيديو', _pickVideo),
          _mediaItem(Icons.attach_file, 'ملف', _pickFile),
          _mediaItem(Icons.contacts_outlined, 'جهة اتصال', _pickContact),
          _mediaItem(Icons.location_on_outlined, 'موقعي', () {
            setState(() => _attachments = false);
            widget.onShareLocation?.call();
          }),
        ],
      );

  Widget _recentGallery(bool dark) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, bottom: 7),
            child: Row(
              children: [
                Icon(Icons.history_rounded, size: 17, color: AppColors.primary),
                const SizedBox(width: 5),
                Text(
                  'الملفات الحديثة',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: dark ? Colors.white : const Color(0xFF263238)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              reverse: true,
              itemCount: _recentAssets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final asset = _recentAssets[index];
                return FutureBuilder<Uint8List?>(
                  future: asset.thumbnailDataWithSize(const ThumbnailSize(150, 150)),
                  builder: (context, snapshot) => GestureDetector(
                    onTap: snapshot.hasData ? () => _sendRecentAsset(asset) : null,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 76,
                        height: 76,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (snapshot.hasData)
                              Image.memory(snapshot.data!, fit: BoxFit.cover)
                            else
                              Container(
                                color: dark ? Colors.white10 : Colors.black12,
                                child: const Center(child: CircularProgressIndicator(strokeWidth: 1.5)),
                              ),
                            if (asset.type == AssetType.video)
                              Positioned(
                                bottom: 5,
                                right: 5,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 14),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );

  Widget _mediaItem(IconData icon, String label, VoidCallback action) => InkWell(
        onTap: action,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            children: [
              CircleAvatar(backgroundColor: AppColors.primary.withOpacity(.1), child: Icon(icon, color: AppColors.primary)),
              const SizedBox(height: 3),
              Text(label, style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
      );
}
