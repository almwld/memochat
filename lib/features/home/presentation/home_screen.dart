import 'package:flutter/material.dart';
import '../../../core/repositories/chat_repository.dart';
import '../../../core/theme/app_icons.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../notifications/presentation/notification_center_screen.dart';
import '../../auth/presentation/auth_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.repository, super.key});
  final ChatRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MemoChat', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(onPressed: () {}, icon: const AppIcon(AppIcons.search)),
          IconButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationCenterScreen())),
            icon: const AppIcon(AppIcons.notifications),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen())),
            icon: const AppIcon(AppIcons.more),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: repository.watchConversations(),
        builder: (context, snapshot) {
          final conversations = snapshot.data ?? const [];
          if (conversations.isEmpty) return const Center(child: Text('لا توجد محادثات بعد'));
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: conversations.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 82),
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              final participant = conversation.participant;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: CircleAvatar(radius: 27, child: Text(participant.displayName.characters.first)),
                title: Text(participant.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(conversation.lastMessage?.text ?? 'ابدأ محادثة جديدة', maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: conversation.unreadCount == 0
                    ? null
                    : CircleAvatar(radius: 12, backgroundColor: const Color(0xFF0A8F83), child: Text(conversation.unreadCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 11))),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(conversation: conversation, repository: repository))),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () {}, child: const AppIcon(AppIcons.chat)),
    );
  }
}
