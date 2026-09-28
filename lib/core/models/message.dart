enum MessageStatus { sending, sent, delivered, read, failed }

enum MessageType { text, image, video, file, audio }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.createdAt,
    required this.type,
    this.text = '',
    this.status = MessageStatus.sent,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final DateTime createdAt;
  final MessageType type;
  final String text;
  final MessageStatus status;
}
