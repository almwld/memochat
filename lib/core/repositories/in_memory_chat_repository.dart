import 'dart:async';
import '../models/chat_user.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import 'chat_repository.dart';

class InMemoryChatRepository implements ChatRepository {
  final StreamController<List<Conversation>> _conversationController =
      StreamController<List<Conversation>>.broadcast();
  final StreamController<List<ChatMessage>> _messageController =
      StreamController<List<ChatMessage>>.broadcast();

  final Conversation _conversation = Conversation(
    id: 'demo',
    participant: ChatUser(id: 'user-2', displayName: 'MemoChat', isOnline: true),
    unreadCount: 2,
  );

  final List<ChatMessage> _messages = <ChatMessage>[
    ChatMessage(
      id: 'welcome',
      conversationId: 'demo',
      senderId: 'user-2',
      createdAt: DateTime(2026, 9, 28, 18, 30),
      type: MessageType.text,
      text: 'مرحباً بك في MemoChat 👋',
    ),
  ];

  @override
  Stream<List<ChatUser>> watchContacts({String query = ''}) => Stream.value(<ChatUser>[]);

  @override
  Future<void> createConversation({required String otherUserId, required String otherUserName, String? otherUserPhoto}) async {}

  @override
  Stream<List<Conversation>> watchConversations() {
    scheduleMicrotask(() => _conversationController.add(<Conversation>[_conversation]));
    return _conversationController.stream;
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    scheduleMicrotask(() => _messageController.add(List.unmodifiable(_messages)));
    return _messageController.stream;
  }

  @override
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String text,
  }) async {
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
    _messages.add(message);
    _messageController.add(List.unmodifiable(_messages));
    return message;
  }
}
