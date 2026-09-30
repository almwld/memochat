import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memochat/features/chat/models/message_model.dart';

void main() {
  test('MessageModel accepts legacy timestamp and coordinate representations', () {
    final message = MessageModel.fromFirestore('m1', {
      'chatId': 'chat',
      'senderId': 'user',
      'senderName': 'User',
      'type': 'location',
      'timestamp': DateTime(2026, 9, 30).toIso8601String(),
      'clientTimestamp': DateTime.now().millisecondsSinceEpoch,
      'locationLat': '15.3694',
      'locationLng': 44.1910,
      'reactions': {'u1': '❤️'},
      'deletedFor': {'u2': true},
      'replyPreview': {'id': 'm0', 'text': 'legacy'},
    });

    expect(message.timestamp, isA<Timestamp>());
    expect(message.locationLat, closeTo(15.3694, 0.00001));
    expect(message.locationLng, closeTo(44.1910, 0.00001));
    expect(message.reactions?['u1'], '❤️');
    expect(message.deletedFor?['u2'], isTrue);
    expect(message.replyPreview?['id'], 'm0');
  });

  test('MessageModel falls back safely for unknown legacy enum values', () {
    final message = MessageModel.fromFirestore('m2', {
      'chatId': 'chat',
      'senderId': 'user',
      'senderName': 'User',
      'type': 'legacy_unknown_type',
      'status': 'legacy_unknown_status',
    });

    expect(message.type, MessageType.text);
    expect(message.status, MessageStatus.sent);
  });
}
