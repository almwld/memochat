import 'dart:async';

import 'package:flutter/material.dart';
import 'package:memochat/core/constants/app_colors.dart';
import 'package:memochat/features/chat/models/message_model.dart';
import 'package:memochat/features/chat/services/chat_service.dart';
import 'package:memochat/presentation/widgets/common/unified_search_bar.dart';

class MessageSearchScreen extends StatefulWidget {
  final String chatId;
  const MessageSearchScreen({super.key, required this.chatId});

  @override
  State<MessageSearchScreen> createState() => _MessageSearchScreenState();
}

class _MessageSearchScreenState extends State<MessageSearchScreen> {
  final _controller = TextEditingController();
  final _service = ChatService();
  Timer? _debounce;
  List<MessageModel> _results = const [];
  bool _loading = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
  }

  void _changed() {
    final value = _controller.text.trim();
    _query = value;
    _debounce?.cancel();
    if (value.isEmpty) {
      if (mounted) setState(() => _results = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), _search);
  }

  Future<void> _search() async {
    final query = _query;
    if (query.isEmpty) return;
    setState(() => _loading = true);
    try {
      final results = await _service.searchMessages(chatId: widget.chatId, query: query);
      if (!mounted || query != _query) return;
      setState(() => _results = results);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر البحث داخل الرسائل')));
    } finally {
      if (mounted && query == _query) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_changed);
    _controller.dispose();
    super.dispose();
  }

  String _preview(MessageModel m) {
    final text = m.text?.trim();
    if (text != null && text.isNotEmpty) return text;
    switch (m.type) {
      case MessageType.image: return '📷 صورة';
      case MessageType.video: return '🎬 فيديو';
      case MessageType.audio: return '🎤 رسالة صوتية';
      case MessageType.file: return '📎 ملف';
      case MessageType.location: return '📍 موقع';
      default: return 'مرفق';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: UnifiedSearchBar(controller: _controller, hintText: 'ابحث داخل الرسائل...'),
        actions: [if (_loading) const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))],
      ),
      body: _query.isEmpty
          ? const Center(child: Text('اكتب كلمة أو عبارة للبحث'))
          : _results.isEmpty && !_loading
              ? const Center(child: Text('لا توجد رسائل مطابقة'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final message = _results[index];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.message_outlined)),
                      title: Text(message.senderName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(_preview(message), maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.chevron_left, color: AppColors.primary),
                      onTap: () => Navigator.of(context).pop(message.id),
                    );
                  },
                ),
    );
  }
}
