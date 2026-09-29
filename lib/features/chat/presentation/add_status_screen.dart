import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:memochat/core/constants/app_colors.dart';
import 'package:memochat/features/chat/models/status_model.dart';
import 'package:memochat/features/chat/services/status_service.dart';

class AddStatusScreen extends StatefulWidget {
  const AddStatusScreen({super.key});

  @override
  State<AddStatusScreen> createState() => _AddStatusScreenState();
}

class _AddStatusScreenState extends State<AddStatusScreen> {
  final ImagePicker _picker = ImagePicker();
  final StatusService _statusService = StatusService();
  final TextEditingController _textController = TextEditingController();

  XFile? _selectedMedia;
  String _mediaType = 'image';
  bool _publishing = false;
  int _textThemeIndex = 0;
  static const _textThemes = <List<Color>>[
    [Color(0xFF0A8F83), Color(0xFF14532D)],
    [Color(0xFF2563EB), Color(0xFF4C1D95)],
    [Color(0xFFDB2777), Color(0xFF7C2D12)],
    [Color(0xFF7C3AED), Color(0xFF1E3A8A)],
    [Color(0xFFEA580C), Color(0xFF9A3412)],
    [Color(0xFF0891B2), Color(0xFF164E63)],
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 88);
    if (file == null || !mounted) return;
    setState(() {
      _selectedMedia = file;
      _mediaType = 'image';
    });
  }

  Future<void> _pickVideo() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 15));
    if (file == null || !mounted) return;
    setState(() {
      _selectedMedia = file;
      _mediaType = 'video';
    });
  }

  String _friendlyStatusError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    if (raw.contains('Media body is required') || raw.contains('media body')) {
      return 'اختر صورة أو فيديو قبل إرسال الحالة.';
    }
    if (raw.contains('permission') || raw.contains('إذن')) {
      return 'تعذر الوصول إلى الوسائط. تحقق من أذونات الصور والفيديو.';
    }
    if (raw.contains('network') || raw.contains('SocketException') || raw.contains('timeout')) {
      return 'تعذر إرسال الحالة بسبب ضعف الاتصال بالإنترنت. حاول مرة أخرى.';
    }
    return 'تعذر نشر الحالة الآن. تحقق من الاتصال وحاول مرة أخرى.';
  }

  Future<void> _publish() async {
    if (_publishing) return;
    final text = _textController.text.trim();
    if (_selectedMedia == null && text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف صورة أو فيديو أو نصاً أولاً')));
      return;
    }

    setState(() => _publishing = true);
    try {
      StoryItem story;
      if (_selectedMedia != null) {
        story = await _statusService.uploadMediaStory(
          file: File(_selectedMedia!.path),
          type: _mediaType,
          duration: _mediaType == 'video' ? const Duration(seconds: 10) : const Duration(seconds: 5),
        );
      } else {
        story = StoryItem(type: 'text', text: text, duration: const Duration(seconds: 5));
      }

      await _statusService.createStatus(stories: [story]);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر نشر الحالة: $error')),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPublish = _selectedMedia != null || _textController.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة حالة'),
        actions: [
          TextButton(
            onPressed: _publishing ? null : _publish,
            child: const Text('حفظ', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Container(
            height: 360,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF162039) : const Color(0xFFF4F6F7),
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: _preview(isDark),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _textController,
            maxLines: 5,
            textDirection: TextDirection.rtl,
            decoration: InputDecoration(
              labelText: 'نص الحالة',
              hintText: 'شارك لحظتك اليوم...',
              filled: true,
              fillColor: isDark ? const Color(0xFF162039) : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_selectedMedia == null) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _textThemes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) => GestureDetector(
                  onTap: () => setState(() => _textThemeIndex = index),
                  child: Container(
                    width: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: _textThemes[index]),
                      shape: BoxShape.circle,
                      border: Border.all(color: _textThemeIndex == index ? Colors.white : Colors.transparent, width: 3),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _publishing ? null : _pickImage,
                  icon: const Icon(Icons.photo_outlined),
                  label: const Text('صورة'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _publishing ? null : _pickVideo,
                  icon: const Icon(Icons.videocam_outlined),
                  label: const Text('فيديو'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _publishing || !canPublish ? null : _publish,
              icon: _publishing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_publishing ? 'جاري الإرسال...' : 'حفظ وإرسال الحالة'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFD7DDDF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'ستختفي الحالة تلقائياً بعد 24 ساعة. الفيديو حتى 15 ثانية.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _preview(bool isDark) {
    if (_selectedMedia != null) {
      if (_mediaType == 'image') {
        return Image.file(File(_selectedMedia!.path), fit: BoxFit.cover);
      }
      return Center(child: Text('فيديو', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 18, fontWeight: FontWeight.w700)));
    }
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: _textThemes[_textThemeIndex]),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_photo_alternate_outlined, size: 54, color: isDark ? Colors.white54 : Colors.black38),
          const SizedBox(height: 10),
          const Text('اختر صورة أو فيديو أو اكتب حالة'),
        ],
      ),
    );
  }
}
