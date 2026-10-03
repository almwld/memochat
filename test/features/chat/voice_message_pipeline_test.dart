import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memochat/features/chat/models/message_model.dart';

void main() {
  test('audio Firestore payload maps to a voice message', () {
    final message = MessageModel.fromFirestore('voice-1', {
      'chatId': 'chat-1',
      'senderId': 'user-1',
      'senderName': 'User',
      'type': 'audio',
      'audioUrl': 'https://example.invalid/voice.m4a',
      'audioDuration': '12',
      'timestamp': Timestamp.now(),
      'status': 'sent',
    });
    expect(message.type, MessageType.audio);
    expect(message.isAudio, isTrue);
    expect(message.audioUrl, contains('voice.m4a'));
    expect(message.audioDuration, '12');
  });
}