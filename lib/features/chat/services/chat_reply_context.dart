import '../models/message_model.dart';

/// Lightweight per-screen reply state consumed by the reliable text sender.
/// It avoids coupling the media/input widget to the chat-room message model.
class ChatReplyContext {
  ChatReplyContext._();
  static final ChatReplyContext instance = ChatReplyContext._();

  final Map<String, MessageModel> _replies = {};

  MessageModel? forChat(String chatId) => _replies[chatId];
  void set(String chatId, MessageModel message) => _replies[chatId] = message;
  void clear(String chatId) => _replies.remove(chatId);
}
