import 'package:flutter/material.dart';
import 'package:memochat/features/chat/models/message_model.dart';
import 'package:memochat/features/chat/services/chat_service.dart';

class StarredMessagesScreen extends StatelessWidget {
  const StarredMessagesScreen({super.key, required this.chatId});
  final String chatId;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الرسائل المحفوظة')),
    body: FutureBuilder<List<MessageModel>>(
      future: ChatService().getStarredMessages(chatId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('تعذر تحميل الرسائل: ' + snapshot.error.toString()));
        final items = snapshot.data ?? const <MessageModel>[];
        if (items.isEmpty) return const Center(child: Text('لا توجد رسائل محفوظة'));
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final m = items[i];
            return Card(child: ListTile(
              leading: const Icon(Icons.star, color: Colors.amber),
              title: Text(m.text?.trim().isNotEmpty == true ? m.text! : _label(m)),
              subtitle: Text(m.senderName),
            ));
          },
        );
      },
    ),
  );

  static String _label(MessageModel m) => switch (m.type) {
    MessageType.image => 'صورة',
    MessageType.video => 'فيديو',
    MessageType.audio => 'رسالة صوتية',
    MessageType.file => 'ملف',
    MessageType.location => 'موقع',
    _ => 'رسالة',
  };
}