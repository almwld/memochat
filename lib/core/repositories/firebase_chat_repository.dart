import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_user.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import 'chat_repository.dart';

class FirebaseChatRepository implements ChatRepository {
  FirebaseChatRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _messages(String id) =>
      _firestore.collection('conversations').doc(id).collection('messages');

  @override
  Stream<List<Conversation>> watchConversations() {
    return _firestore.collection('conversations').snapshots().map((snapshot) => snapshot.docs.map((doc) {
      final data = doc.data();
      return Conversation(
        id: doc.id,
        participant: ChatUser(
          id: data['participantId'] as String? ?? '',
          displayName: data['participantName'] as String? ?? 'مستخدم',
          avatarUrl: data['participantAvatar'] as String?,
          isOnline: data['isOnline'] as bool? ?? false,
        ),
        unreadCount: (data['unreadCount'] as num?)?.toInt() ?? 0,
      );
    }).toList());
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    return _messages(conversationId).orderBy('createdAt').snapshots().map((snapshot) => snapshot.docs.map((doc) {
      final data = doc.data();
      final timestamp = data['createdAt'];
      return ChatMessage(
        id: doc.id,
        conversationId: conversationId,
        senderId: data['senderId'] as String? ?? '',
        createdAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
        type: MessageType.values.firstWhere((value) => value.name == data['type'], orElse: () => MessageType.text),
        text: data['text'] as String? ?? '',
        status: MessageStatus.values.firstWhere((value) => value.name == data['status'], orElse: () => MessageStatus.sent),
        isMine: (data['senderId'] as String?) == 'me',
      );
    }).toList());
  }

  @override
  Future<ChatMessage> sendMessage({required String conversationId, required String text}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(text, 'text', 'Message cannot be empty');
    final doc = _messages(conversationId).doc();
    final now = DateTime.now();
    final message = ChatMessage(
      id: doc.id,
      conversationId: conversationId,
      senderId: 'me',
      createdAt: now,
      type: MessageType.text,
      text: trimmed,
      status: MessageStatus.sent,
      isMine: true,
    );
    await doc.set({
      'senderId': 'me',
      'text': trimmed,
      'type': message.type.name,
      'status': message.status.name,
      'createdAt': Timestamp.fromDate(now),
      'clientTimestamp': now.microsecondsSinceEpoch,
    });
    return message;
  }
}
