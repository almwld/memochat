import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationInboxItem {
  const NotificationInboxItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.route,
    this.read = false,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? route;
  final bool read;

  NotificationInboxItem copyWith({bool? read}) => NotificationInboxItem(
    id: id,
    title: title,
    body: body,
    createdAt: createdAt,
    route: route,
    read: read ?? this.read,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'route': route,
    'read': read,
  };

  factory NotificationInboxItem.fromJson(Map<String, dynamic> json) => NotificationInboxItem(
    id: json['id'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    route: json['route'] as String?,
    read: (json['read'] as bool?) ?? false,
  );
}

class NotificationInbox {
  NotificationInbox({SharedPreferences? preferences}) : _preferences = preferences;
  static const _key = 'notification_inbox_v1';
  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  Future<List<NotificationInboxItem>> read() async {
    final values = (await _prefs).getStringList(_key) ?? const [];
    return values.map((value) => NotificationInboxItem.fromJson(jsonDecode(value) as Map<String, dynamic>)).toList();
  }

  Future<void> add(NotificationInboxItem item) async {
    final values = await read();
    values.removeWhere((existing) => existing.id == item.id);
    values.insert(0, item);
    final limited = values.take(200).map((value) => jsonEncode(value.toJson())).toList();
    await (await _prefs).setStringList(_key, limited);
  }

  Future<void> markRead(String id) async {
    final values = await read();
    final updated = values.map((item) => item.id == id ? item.copyWith(read: true) : item);
    await (await _prefs).setStringList(_key, updated.map((value) => jsonEncode(value.toJson())).toList());
  }
}
