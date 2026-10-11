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

  test('preserves voice-room invite routing and identity', () {
    final notification = AppNotification.fromRemote({
      'type': 'voice_room_invite',
      'notificationId': 'notice-room-1',
      'inviteId': 'invite-1',
      'roomId': 'room-1',
      'senderId': 'user-2',
      'route': 'voice_room:room-1',
      'title': 'غرفة الأصدقاء',
      'body': 'تمت دعوتك إلى غرفة صوتية',
    });
    expect(notification.type, NotificationType.voiceRoomInvite);
    expect(notification.channel, NotificationChannel.system);
    expect(notification.extraData['inviteId'], 'invite-1');
    expect(notification.extraData['roomId'], 'room-1');
    expect(notification.route, 'voice_room:room-1');
  });

  test('preserves friend-request identity for notification actions', () {
    final notification = AppNotification.fromRemote({
      'type': 'friend_request',
      'notificationId': 'notice-friend-1',
      'requestId': 'request-1',
      'senderId': 'user-2',
      'route': 'contacts:friend_request',
      'title': 'طلب صداقة جديد',
      'body': 'أرسل لك طلب صداقة',
    });
    expect(notification.type, NotificationType.friendRequest);
    expect(notification.extraData['requestId'], 'request-1');
    expect(notification.channel, NotificationChannel.system);
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
