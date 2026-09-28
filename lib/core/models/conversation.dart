import 'chat_user.dart';
import 'message.dart';

class Conversation {
  const Conversation({
    required this.id,
    required this.participant,
    this.lastMessage,
    this.unreadCount = 0,
  });

  final String id;
  final ChatUser participant;
  final ChatMessage? lastMessage;
  final int unreadCount;
}
