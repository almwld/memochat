import 'dart:convert';

enum NotificationType {
  textMessage,
  imageMessage,
  videoMessage,
  fileMessage,
  audioMessage,
  reply,
  system,
  general,
}

enum NotificationPriority { low, normal, high }

enum NotificationChannel { messages, calls, missedCalls, system }

extension NotificationTypeWireName on NotificationType {
  String get wireName => switch (this) {
        NotificationType.textMessage => 'text_message',
        NotificationType.imageMessage => 'image_message',
        NotificationType.videoMessage => 'video_message',
        NotificationType.fileMessage => 'file_message',
        NotificationType.audioMessage => 'audio_message',
        NotificationType.reply => 'reply',
        NotificationType.system => 'system',
        NotificationType.general => 'general',
      };

}

abstract final class NotificationTypeCodec {
  static NotificationType parse(String? value) => NotificationType.values.firstWhere(
        (type) => type.wireName == value,
        orElse: () => NotificationType.general,
      );
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    this.chatId,
    this.messageId,
    this.senderId,
    this.route,
    this.priority = NotificationPriority.normal,
    this.channel = NotificationChannel.system,
    this.sound = true,
    this.vibration = true,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime timestamp;
  final String? chatId;
  final String? messageId;
  final String? senderId;
  final String? route;
  final NotificationPriority priority;
  final NotificationChannel channel;
  final bool sound;
  final bool vibration;

  String get dedupeKey => messageId ?? '$type:$id';

  Map<String, dynamic> toJson() => {
        'type': type.wireName,
        'notificationId': id,
        'chatId': chatId,
        'messageId': messageId,
        'senderId': senderId,
        'route': route,
        'timestamp': timestamp.toIso8601String(),
        'title': title,
        'body': body,
      };

  String encode() => jsonEncode(toJson());

  factory AppNotification.fromRemote(Map<String, dynamic> data, {
    String? fallbackId,
    String? fallbackTitle,
    String? fallbackBody,
  }) {
    final type = NotificationTypeCodec.parse(data['type']?.toString());
    final messageId = data['messageId']?.toString();
    final id = data['notificationId']?.toString() ?? messageId ?? fallbackId ?? DateTime.now().microsecondsSinceEpoch.toString();
    final route = data['route']?.toString();
    return AppNotification(
      id: id,
      type: type,
      title: data['title']?.toString() ?? fallbackTitle ?? 'MemoChat',
      body: data['body']?.toString() ?? fallbackBody ?? '',
      timestamp: DateTime.tryParse(data['timestamp']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      chatId: data['chatId']?.toString(),
      messageId: messageId,
      senderId: data['senderId']?.toString(),
      route: route,
      priority: data['priority']?.toString() == 'high' ? NotificationPriority.high : NotificationPriority.normal,
      channel: NotificationChannel.messages,
      sound: data['sound']?.toString() != 'false',
      vibration: data['vibration']?.toString() != 'false',
    );
  }
}
