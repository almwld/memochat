import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memochat/features/chat/models/message_model.dart';

void main() {
  test('MessageModel tolerates legacy timestamp representations', () {
    final message = MessageModel.fromFirestore('m1', {
      'chatId': 'c1',
      'senderId': 'u1',
      'senderName': 'User',
      'type': 'text',
      'timestamp': '2026-09-30T10:20:00.000Z',
      'clientTimestamp': DateTime.utc(2026, 9, 30, 10, 19),
      'readAt': '2026-09-30T10:21:00.000Z',
      'deliveredAt': DateTime.utc(2026, 9, 30, 10, 20),
      'editedAt': 1780222860000,
      'pinnedAt': null,
    });

    expect(message.timestamp, isA<Timestamp>());
    expect(message.clientTimestamp, isA<Timestamp>());
    expect(message.readAt, isA<Timestamp>());
    expect(message.deliveredAt, isA<Timestamp>());
    expect(message.editedAt, isA<Timestamp>());
    expect(message.pinnedAt, isNull);
  });

  test('MessageModel keeps Firestore timestamps unchanged', () {
    final timestamp = Timestamp.fromDate(DateTime.utc(2026, 9, 30, 10, 20));
    final message = MessageModel.fromFirestore('m2', {
      'chatId': 'c1',
      'senderId': 'u1',
      'senderName': 'User',
      'type': 'text',
      'timestamp': timestamp,
      'readAt': timestamp,
    });

    expect(message.timestamp, timestamp);
    expect(message.readAt, timestamp);
  });
}
