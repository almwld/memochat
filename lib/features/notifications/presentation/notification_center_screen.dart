import 'package:flutter/material.dart';

import '../../../core/notifications/notification_inbox.dart';
import '../../../core/services/notification_history_service.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/ui/memo_chat_ui_tokens.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final _inbox = NotificationInbox();
  final _history = NotificationHistoryService();

  Future<void> _markAllRead() async {
    await _history.markAllRead();
    await _inbox.markAllRead();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          IconButton(
            tooltip: 'تحديد الكل كمقروء',
            onPressed: _markAllRead,
            icon: const Icon(Icons.done_all_rounded),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: _history.watch(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('تعذر تحميل الإشعارات'));
          }
          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return FutureBuilder<List<NotificationInboxItem>>(
              future: _inbox.read(),
              builder: (context, fallback) {
                final items = fallback.data ?? const <NotificationInboxItem>[];
                if (items.isEmpty) {
                  return const Center(child: Text('لا توجد إشعارات'));
                }
                return _buildInboxFallback(items);
              },
            );
          }
          final unread = docs.where((doc) => doc.data()['read'] != true).length;
          return Column(
            children: [
              if (unread > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      '$unread غير مقروء',
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final read = data['read'] == true;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: MemoChatUiTokens.radiusMd,
                        vertical: 4,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: read
                            ? scheme.surfaceContainerHighest
                            : MemoChatUiTokens.accent.withOpacity(.12),
                        child: AppIcon(
                          AppIcons.notifications,
                          color: read
                              ? scheme.onSurfaceVariant
                              : MemoChatUiTokens.accent,
                        ),
                      ),
                      title: Text(
                        data['title']?.toString() ?? 'إشعار',
                        style: TextStyle(
                          fontWeight:
                              read ? FontWeight.w500 : FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(data['body']?.toString() ?? ''),
                      onTap: () async {
                        await _history.markRead(doc.id);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInboxFallback(List<NotificationInboxItem> items) =>
      ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            leading: const CircleAvatar(
              child: AppIcon(AppIcons.notifications),
            ),
            title: Text(item.title),
            subtitle: Text(item.body),
            onTap: () async {
              await _inbox.markRead(item.id);
              if (mounted) setState(() {});
            },
          );
        },
      );
}
