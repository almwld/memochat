import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PendingMessage {
  const PendingMessage({
    required this.id,
    required this.conversationId,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String text;
  final DateTime createdAt;

  Map<String, Object> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
  };

  factory PendingMessage.fromJson(Map<String, dynamic> json) => PendingMessage(
    id: json['id'] as String,
    conversationId: json['conversationId'] as String,
    text: json['text'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class PendingMessageQueue {
  PendingMessageQueue({SharedPreferences? preferences}) : _preferences = preferences;

  static const _key = 'pending_messages_v1';
  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  Future<List<PendingMessage>> read() async {
    final values = (await _prefs).getStringList(_key) ?? const [];
    return values
        .map((value) => PendingMessage.fromJson(jsonDecode(value) as Map<String, dynamic>))
        .toList();
  }

  Future<void> enqueue(PendingMessage message) async {
    final values = await read();
    if (values.any((item) => item.id == message.id)) return;
    values.add(message);
    await (await _prefs).setStringList(_key, values.map((item) => jsonEncode(item.toJson())).toList());
  }

  Future<void> remove(String id) async {
    final values = await read();
    values.removeWhere((item) => item.id == id);
    await (await _prefs).setStringList(_key, values.map((item) => jsonEncode(item.toJson())).toList());
  }

  Future<void> clear() async => (await _prefs).remove(_key);

  Future<void> flush(Future<void> Function(PendingMessage message) sender) async {
    final pending = await read();
    for (final message in pending) {
      try {
        await sender(message);
        await remove(message.id);
      } catch (_) {
        // Keep failed messages queued for the next connectivity/retry cycle.
      }
    }
  }
}
