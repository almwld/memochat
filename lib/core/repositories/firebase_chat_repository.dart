import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_user.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import 'chat_repository.dart';

class FirebaseChatRepository implements ChatRepository {
  FirebaseChatRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> _chats() =>
      _firestore.collection('chats');

  CollectionReference<Map<String, dynamic>> _messages(String id) =>
      _chats().doc(id).collection('messages');

  @override
  Stream<List<ChatUser>> watchContacts({String query = ''}) {
    final normalized = query.trim().toLowerCase();
    if (_uid.isEmpty) return const Stream.empty();
    return _firestore.collection('users').limit(100).snapshots().map((snapshot) => snapshot.docs.map((doc) {
      if (doc.id == _uid) return null;
      final data = doc.data();
      final name = data['displayName']?.toString() ?? 'مستخدم';
      final username = data['username']?.toString() ?? '';
      if (normalized.isNotEmpty && !name.toLowerCase().contains(normalized) && !username.toLowerCase().contains(normalized)) return null;
      return ChatUser(id: doc.id, displayName: name, username: username.isEmpty ? null : username, avatarUrl: data['photoUrl']?.toString() ?? data['photoURL']?.toString(), isOnline: data['isOnline'] == true);
    }).whereType<ChatUser>().toList());
  }

  @override
  Future<String> createConversation({required String otherUserId, required String otherUserName, String? otherUserPhoto}) async {
    if (_uid.isEmpty) throw StateError('يرجى تسجيل الدخول');
    final ids = [_uid, otherUserId]..sort();
    final me = FirebaseAuth.instance.currentUser;
    final chatId = ids.join('_');
    await _chats().doc(chatId).set({'participants': ids, 'participantNames': {_uid: me?.displayName ?? 'مستخدم', otherUserId: otherUserName}, 'participantPhotos': {_uid: me?.photoURL ?? '', otherUserId: otherUserPhoto ?? ''}, 'updatedAt': FieldValue.serverTimestamp(), 'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    return chatId;
  }

  @override
  Stream<List<Conversation>> watchConversations() {
    if (_uid.isEmpty) return const Stream.empty();

    return _chats()
        .where('participants', arrayContains: _uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              final ids = List<String>.from(
                (data['participants'] as List?)
                        ?.map((e) => e.toString()) ??
                    const [],
              );
              final other =
                  ids.firstWhere((id) => id != _uid, orElse: () => '');
              final names = Map<String, dynamic>.from(
                data['participantNames'] as Map? ?? const {},
              );
              final photos = Map<String, dynamic>.from(
                data['participantPhotos'] as Map? ?? const {},
              );
              final preview = data['lastMessage']?.toString() ?? '';
              final previewTime = data['updatedAt'];
              final previewDate = previewTime is Timestamp
                  ? previewTime.toDate()
                  : DateTime.now();

              return Conversation(
                id: doc.id,
                participant: ChatUser(
                  id: other,
                  displayName: names[other]?.toString() ?? 'مستخدم',
                  avatarUrl: photos[other]?.toString(),
                  isOnline: false,
                ),
                lastMessage: preview.isEmpty
                    ? null
                    : ChatMessage(
                        id: 'preview',
                        conversationId: doc.id,
                        senderId:
                            data['lastMessageSenderId']?.toString() ?? '',
                        createdAt: previewDate,
                        type: MessageType.text,
                        text: preview,
                        status: MessageStatus.sent,
                        isMine: data['lastMessageSenderId'] == _uid,
                      ),
                unreadCount: (data['unreadCount'] as num?)?.toInt() ?? 0,
              );
            }).toList());
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    return _messages(conversationId)
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              final timestamp = data['timestamp'];
              return ChatMessage(
                id: doc.id,
                conversationId: conversationId,
                senderId: data['senderId'] as String? ?? '',
                createdAt: timestamp is Timestamp
                    ? timestamp.toDate()
                    : DateTime.now(),
                type: MessageType.values.firstWhere(
                  (value) => value.name == data['type'],
                  orElse: () => MessageType.text,
                ),
                text: data['text'] as String? ?? '',
                status: MessageStatus.values.firstWhere(
                  (value) => value.name == data['status'],
                  orElse: () => MessageStatus.sent,
                ),
                isMine: (data['senderId'] as String?) == _uid,
              );
            }).toList());
  }

  @override
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(text, 'text', 'Message cannot be empty');
    }
    if (_uid.isEmpty) throw StateError('يرجى تسجيل الدخول');

    final doc = _messages(conversationId).doc();
    final now = DateTime.now();
    await doc.set({
      'chatId': conversationId,
      'senderId': _uid,
      'text': trimmed,
      'type': MessageType.text.name,
      'status': MessageStatus.sent.name,
      'timestamp': Timestamp.fromDate(now),
      'clientTimestamp': now.microsecondsSinceEpoch,
    });
    await _chats().doc(conversationId).set({
      'lastMessage': trimmed,
      'lastMessageSenderId': _uid,
      'updatedAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));

    return ChatMessage(
      id: doc.id,
      conversationId: conversationId,
      senderId: _uid,
      createdAt: now,
      type: MessageType.text,
      text: trimmed,
      status: MessageStatus.sent,
      isMine: true,
    );
  }
}
