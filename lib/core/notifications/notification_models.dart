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
  call,
}

enum NotificationPriority { low, normal, high }

enum NotificationChannel { messages, calls, system }

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
        NotificationType.call => 'call',
      };

}

abstract final class NotificationTypeCodec {
  static NotificationType parse(String? value) {
    final normalized = value?.trim().toLowerCase();
    switch (normalized) {
      case 'incoming_call':
      case 'incoming_video_call':
      case 'call':
        return NotificationType.call;
      case 'new_message':
      case 'chat_message':
      case 'message':
      case 'text':
      case 'text_message':
        return NotificationType.textMessage;
      case 'image':
      case 'photo':
      case 'image_message':
        return NotificationType.imageMessage;
      case 'video':
      case 'video_message':
        return NotificationType.videoMessage;
      case 'audio':
      case 'voice':
      case 'audio_message':
        return NotificationType.audioMessage;
      case 'file':
      case 'document':
      case 'file_message':
        return NotificationType.fileMessage;
      case 'reply':
      case 'message_reply':
        return NotificationType.reply;
      case 'system_update':
      case 'system_security':
      case 'system_maintenance':
      case 'system_feature':
      case 'system':
        return NotificationType.system;
      default:
        return NotificationType.values.firstWhere(
          (type) => type.wireName == normalized,
          orElse: () => NotificationType.general,
        );
    }
  }
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
    this.callId,
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
  final String? callId;
  final String? senderId;
  final String? route;
  final NotificationPriority priority;
  final NotificationChannel channel;
  final bool sound;
  final bool vibration;

  String get dedupeKey => callId ?? messageId ?? '$type:$id';

  Map<String, dynamic> toJson() => {
        'type': type.wireName,
        'notificationId': id,
        'chatId': chatId,
        'messageId': messageId,
        'callId': callId,
        'senderId': senderId,
        'route': route,
        'timestamp': timestamp.toIso8601String(),
        'title': title,
        'body': body,
      };

  String encode() => jsonEncode(toJson());

  bool get isCall => type == NotificationType.call || (callId?.isNotEmpty ?? false);

  factory AppNotification.fromRemote(Map<String, dynamic> data, {
    String? fallbackId,
    String? fallbackTitle,
    String? fallbackBody,
  }) {
    final type = NotificationTypeCodec.parse(data['type']?.toString());
    final messageId = data['messageId']?.toString();
    final callId = data['callId']?.toString();
    final id = data['notificationId']?.toString() ?? messageId ?? fallbackId ?? DateTime.now().microsecondsSinceEpoch.toString();
    final route = data['route']?.toString() ?? (callId != null && callId.isNotEmpty ? 'call:$callId' : null);
    return AppNotification(
      id: id,
      type: type,
      title: data['title']?.toString() ?? data['callerName']?.toString() ?? data['senderName']?.toString() ?? fallbackTitle ?? 'MemoChat',
      body: data['body']?.toString() ?? fallbackBody ?? (type == NotificationType.call
          ? ((data['isVideo']?.toString().toLowerCase() == 'true' || data['callType']?.toString().toLowerCase() == 'video')
              ? 'مكالمة فيديو واردة'
              : 'مكالمة صوتية واردة')
          : ''),
      timestamp: DateTime.tryParse(data['timestamp']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      chatId: data['chatId']?.toString(),
      messageId: messageId,
      callId: callId,
      senderId: data['senderId']?.toString(),
      route: route,
      priority: data['priority']?.toString() == 'high' ? NotificationPriority.high : NotificationPriority.normal,
      channel: type == NotificationType.call || (callId?.isNotEmpty ?? false)
          ? NotificationChannel.calls
          : type == NotificationType.system || type == NotificationType.general
              ? NotificationChannel.system
              : NotificationChannel.messages,
      sound: data['sound'] != false && data['sound']?.toString().toLowerCase() != 'false',
      vibration: data['vibration'] != false && data['vibration']?.toString().toLowerCase() != 'false',
    );
  }
}
