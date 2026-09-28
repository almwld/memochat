import 'package:flutter/material.dart';
import '../../../core/notifications/notification_inbox.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final _inbox = NotificationInbox();
  late Future<List<NotificationInboxItem>> _items;

  @override
  void initState() {
    super.initState();
    _items = _inbox.read();
  }

  Future<void> _refresh() async {
    setState(() => _items = _inbox.read());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات')),
      body: FutureBuilder<List<NotificationInboxItem>>(
        future: _items,
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <NotificationInboxItem>[];
          if (items.isEmpty) return const Center(child: Text('لا توجد إشعارات'));
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: item.read ? Colors.grey.shade200 : const Color(0xFFE0F2F1),
                    child: Icon(Icons.notifications_none_rounded, color: item.read ? Colors.grey : const Color(0xFF0A8F83)),
                  ),
                  title: Text(item.title, style: TextStyle(fontWeight: item.read ? FontWeight.w500 : FontWeight.w700)),
                  subtitle: Text(item.body),
                  onTap: () async {
                    await _inbox.markRead(item.id);
                    await _refresh();
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
