import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_models.dart';

class NotificationInboxItem {
  const NotificationInboxItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.type = NotificationType.general,
    this.chatId,
    this.messageId,
    this.callId,
    this.senderId,
    this.route,
    this.read = false,
  });
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final NotificationType type;
  final String? chatId;
  final String? messageId;
  final String? callId;
  final String? senderId;
  final String? route;
  final bool read;

  factory NotificationInboxItem.fromNotification(AppNotification n) => NotificationInboxItem(
    id: n.id, title: n.title, body: n.body, createdAt: n.timestamp, type: n.type,
    chatId: n.chatId, messageId: n.messageId, callId: n.callId, senderId: n.senderId, route: n.route,
  );
  NotificationInboxItem copyWith({bool? read}) => NotificationInboxItem(
    id: id, title: title, body: body, createdAt: createdAt, type: type,
    chatId: chatId, messageId: messageId, callId: callId, senderId: senderId, route: route, read: read ?? this.read,
  );
  Map<String, Object?> toJson() => {
    'id': id, 'title': title, 'body': body, 'createdAt': createdAt.toIso8601String(), 'type': type.wireName,
    'chatId': chatId, 'messageId': messageId, 'callId': callId, 'senderId': senderId, 'route': route, 'read': read,
  };
  factory NotificationInboxItem.fromJson(Map<String, dynamic> json) => NotificationInboxItem(
    id: json['id'] as String, title: json['title'] as String, body: json['body'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String), type: NotificationTypeCodec.parse(json['type'] as String?),
    chatId: json['chatId'] as String?, messageId: json['messageId'] as String?, callId: json['callId'] as String?,
    senderId: json['senderId'] as String?, route: json['route'] as String?, read: (json['read'] as bool?) ?? false,
  );
}

class NotificationInbox {
  NotificationInbox({SharedPreferences? preferences}) : _preferences = preferences;
  static const _key = 'notification_inbox_v2';
  static const _dedupeKey = 'notification_dedupe_v1';
  SharedPreferences? _preferences;
  Future<SharedPreferences> get _prefs async => _preferences ??= await SharedPreferences.getInstance();
  Future<List<NotificationInboxItem>> read() async {
    final values = (await _prefs).getStringList(_key) ?? const [];
    return values.map((value) => NotificationInboxItem.fromJson(jsonDecode(value) as Map<String, dynamic>)).toList();
  }
  Future<bool> claim(String key) async {
    final prefs = await _prefs;
    final values = (prefs.getStringList(_dedupeKey) ?? const []).toSet();
    if (!values.add(key)) return false;
    final retained = values.toList();
    if (retained.length > 500) retained.removeRange(0, retained.length - 500);
    await prefs.setStringList(_dedupeKey, retained);
    return true;
  }
  Future<bool> addNotification(AppNotification notification) async {
    if (!await claim(notification.dedupeKey)) return false;
    await add(NotificationInboxItem.fromNotification(notification));
    return true;
  }
  Future<void> add(NotificationInboxItem item) async {
    final values = await read();
    values.removeWhere((existing) => existing.id == item.id);
    values.insert(0, item);
    await (await _prefs).setStringList(_key, values.take(200).map((v) => jsonEncode(v.toJson())).toList());
  }
  Future<int> unreadCount() async => (await read()).where((item) => !item.read).length;
  Future<void> markRead(String id) async {
    final values = await read();
    final updated = values.map((item) => item.id == id ? item.copyWith(read: true) : item);
    await (await _prefs).setStringList(_key, updated.map((value) => jsonEncode(value.toJson())).toList());
  }
}
