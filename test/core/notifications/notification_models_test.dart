import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:memochat/core/notifications/notification_models.dart';

void main() {
  test('parses the canonical message payload', () {
    final notification = AppNotification.fromRemote({
      'type': 'text_message',
      'notificationId': 'n-1',
      'messageId': 'm-1',
      'chatId': 'chat-1',
      'senderId': 'user-2',
      'title': 'رسالة جديدة',
      'body': 'مرحبا',
      'route': 'chat:chat-1',
    });
    expect(notification.type, NotificationType.textMessage);
    expect(notification.dedupeKey, 'm-1');
    expect(jsonDecode(notification.encode())['chatId'], 'chat-1');
  });

  test('uses call id for call deduplication and routing', () {
    final notification = AppNotification.fromRemote({
      'type': 'incoming_video_call',
      'callId': 'call-1',
      'title': 'مكالمة فيديو واردة',
      'body': 'مستخدم',
    });
    expect(notification.isCall, isTrue);
    expect(notification.channel, NotificationChannel.calls);
    expect(notification.dedupeKey, 'call-1');
    expect(notification.route, 'call:call-1');
  });
}
