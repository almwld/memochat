import 'dart:convert';

enum NotificationType {
  textMessage,
  imageMessage,
  videoMessage,
  fileMessage,
  audioMessage,
  reply,
  incomingCall,
  missedCall,
  incomingVideoCall,
  missedVideoCall,
  callEnded,
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
        NotificationType.incomingCall => 'incoming_call',
        NotificationType.missedCall => 'missed_call',
        NotificationType.incomingVideoCall => 'incoming_video_call',
        NotificationType.missedVideoCall => 'missed_video_call',
        NotificationType.callEnded => 'call_ended',
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
    this.callId,
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
  final String? callId;
  final String? route;
  final NotificationPriority priority;
  final NotificationChannel channel;
  final bool sound;
  final bool vibration;

  bool get isCall => type == NotificationType.incomingCall ||
      type == NotificationType.incomingVideoCall ||
      type == NotificationType.missedCall ||
      type == NotificationType.missedVideoCall ||
      type == NotificationType.callEnded;

  String get dedupeKey => messageId ?? callId ?? '$type:$id';

  Map<String, dynamic> toJson() => {
        'type': type.wireName,
        'notificationId': id,
        'chatId': chatId,
        'messageId': messageId,
        'senderId': senderId,
        'callId': callId,
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
    final callId = data['callId']?.toString();
    final messageId = data['messageId']?.toString();
    final id = data['notificationId']?.toString() ?? messageId ?? callId ?? fallbackId ?? DateTime.now().microsecondsSinceEpoch.toString();
    final route = data['route']?.toString() ?? (callId == null ? null : 'call:$callId');
    return AppNotification(
      id: id,
      type: type,
      title: data['title']?.toString() ?? fallbackTitle ?? 'MemoChat',
      body: data['body']?.toString() ?? fallbackBody ?? '',
      timestamp: DateTime.tryParse(data['timestamp']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      chatId: data['chatId']?.toString(),
      messageId: messageId,
      senderId: data['senderId']?.toString(),
      callId: callId,
      route: route,
      priority: data['priority']?.toString() == 'high' ? NotificationPriority.high : NotificationPriority.normal,
      channel: callId == null ? NotificationChannel.messages : NotificationChannel.calls,
      sound: data['sound']?.toString() != 'false',
      vibration: data['vibration']?.toString() != 'false',
    );
  }
}
