import '../models/conversation.dart';
import '../models/message.dart';

abstract interface class ChatRepository {
  Stream<List<Conversation>> watchConversations();

  Stream<List<ChatMessage>> watchMessages(String conversationId);

  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String text,
  });
}
