import 'dart:async';
import '../models/chat_user.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import 'chat_repository.dart';

class InMemoryChatRepository implements ChatRepository {
  InMemoryChatRepository()
      : _conversationController = StreamController<List<Conversation>>.broadcast(),
        _messageControllers = {};

  final StreamController<List<Conversation>> _conversationController;
  final Map<String, StreamController<List<ChatMessage>>> _messageControllers;
  final List<Conversation> _conversations = [
    Conversation(id: 'demo', participant: ChatUser(id: 'user-2', displayName: 'MemoChat', isOnline: true), unreadCount: 2),
  ];
  final Map<String, List<ChatMessage>> _messages = {
    'demo': [
      ChatMessage(
        id: 'welcome',
        conversationId: 'demo',
        senderId: 'user-2',
        createdAt: DateTime(2026, 9, 28, 18, 30),
        type: MessageType.text,
        text: 'مرحباً بك في MemoChat 👋',
      ),
    ],
  ];

  @override
  Stream<List<Conversation>> watchConversations() {
    scheduleMicrotask(() => _conversationController.add(List.unmodifiable(_conversations)));
    return _conversationController.stream;
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    final controller = _messageControllers.putIfAbsent(conversationId, () => StreamController<List<ChatMessage>>.broadcast());
    scheduleMicrotask(() => controller.add(List.unmodifiable(_messages[conversationId] ?? [])));
    return controller.stream;
  }

  @override
  Future<ChatMessage> sendMessage({required String conversationId, required String text}) async {
    final message = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      conversationId: conversationId,
      senderId: 'me',
      createdAt: DateTime.now(),
      type: MessageType.text,
      text: text.trim(),
      status: MessageStatus.sent,
      isMine: true,
    );
    final messages = _messages.putIfAbsent(conversationId, () => []);
    messages.add(message);
    _messageControllers[conversationId]?.add(List.unmodifiable(messages));
    return message;
  }
}
