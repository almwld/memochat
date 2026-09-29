import '../models/chat_user.dart';
import '../models/conversation.dart';
import '../models/message.dart';

abstract interface class ChatRepository {
  Stream<List<Conversation>> watchConversations();
  Stream<List<ChatMessage>> watchMessages(String conversationId);
  Stream<List<ChatUser>> watchContacts({String query = ''});
  Future<void> createConversation({required String otherUserId, required String otherUserName, String? otherUserPhoto});
  Future<ChatMessage> sendMessage({required String conversationId, required String text});
}
