import 'chat_user.dart';
import 'message.dart';

class Conversation {
  const Conversation({
    required this.id,
    required this.participant,
    this.lastMessage,
    this.updatedAt,
    this.unreadCount = 0,
    this.isArchived = false,
    this.isGroup = false,
    this.isPinned = false,
    this.isMuted = false,
    this.isTyping = false,
  });

  final String id;
  final ChatUser participant;
  final ChatMessage? lastMessage;
  /// The conversation document's canonical activity timestamp.
  /// Unlike [lastMessage], this also exists for newly-created empty chats.
  final DateTime? updatedAt;
  final int unreadCount;
  final bool isArchived;
  final bool isGroup;
  final bool isPinned;
  final bool isMuted;
  final bool isTyping;
}
