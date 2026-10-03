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
    final normalized = query.trim().toLowerCase().replaceFirst(RegExp(r'^@'), '');
    if (_uid.isEmpty) return const Stream.empty();

    Query<Map<String, dynamic>> source;
    if (normalized.isNotEmpty && normalized.startsWith('memo_')) {
      source = _firestore.collection('users').where('publicId', isEqualTo: normalized).limit(10);
    } else {
      source = _firestore.collection('users').limit(100);
    }

    return source.snapshots().map((snapshot) => snapshot.docs.map((doc) {
      if (doc.id == _uid) return null;
      final data = doc.data();
      final name = data['displayName']?.toString() ?? 'مستخدم';
      final username = data['username']?.toString() ?? '';
      final publicId = data['publicId']?.toString() ?? username;
      final matches = normalized.isEmpty ||
          name.toLowerCase().contains(normalized) ||
          username.toLowerCase().contains(normalized) ||
          publicId.toLowerCase().contains(normalized);
      if (!matches) return null;
      return ChatUser(
        id: doc.id,
        displayName: name,
        username: username.isEmpty ? null : username,
        avatarUrl: data['photoUrl']?.toString() ?? data['photoURL']?.toString(),
        isOnline: data['isOnline'] == true,
      );
    }).whereType<ChatUser>().toList());
  }

  @override
  Future<String> createConversation({required String otherUserId, required String otherUserName, String? otherUserPhoto}) async {
    if (_uid.isEmpty) throw StateError('يرجى تسجيل الدخول');
    final ids = [_uid, otherUserId]..sort();
    final me = FirebaseAuth.instance.currentUser;
    final chatId = ids.join('_');
    final ref = _chats().doc(chatId);
    final existing = await ref.get();
    if (existing.exists) {
      final existingParticipants = List<String>.from(
        (existing.data()?['participants'] as List?)?.map((e) => e.toString()) ?? const [],
      );
      if (existingParticipants.length == 2 &&
          existingParticipants.contains(_uid) &&
          existingParticipants.contains(otherUserId)) {
        return chatId;
      }
      throw StateError('معرّف المحادثة مستخدم لمستخدمين مختلفين');
    }

    await ref.set({
      'participants': ids,
      'participantNames': {
        _uid: me?.displayName ?? 'مستخدم',
        otherUserId: otherUserName,
      },
      'participantPhotos': {
        _uid: me?.photoURL ?? '',
        otherUserId: otherUserPhoto ?? '',
      },
      'participantDetails': {
        _uid: {
          'name': me?.displayName ?? 'مستخدم',
          'photoUrl': me?.photoURL ?? '',
        },
        otherUserId: {
          'name': otherUserName,
          'photoUrl': otherUserPhoto ?? '',
        },
      },
      'isGroup': false,
      'isArchived': false,
      'isPinned': false,
      'isMuted': false,
      'unreadCount': {_uid: 0, otherUserId: 0},
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
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
              // ChatService stores participant metadata under participantDetails.
              // Read both schemas so every persisted chat remains visible here.
              final details = Map<String, dynamic>.from(
                data['participantDetails'] as Map? ?? const {},
              );
              final otherDetails = details[other] is Map
                  ? Map<String, dynamic>.from(details[other] as Map)
                  : const <String, dynamic>{};
              final otherName = names[other]?.toString() ??
                  otherDetails['name']?.toString() ??
                  'مستخدم';
              final otherPhoto = photos[other]?.toString() ??
                  otherDetails['photoUrl']?.toString();
              final preview = data['lastMessage']?.toString() ?? '';
              final previewTime = data['updatedAt'];
              final previewDate = previewTime is Timestamp
                  ? previewTime.toDate()
                  : DateTime.now();

              return Conversation(
                id: doc.id,
                participant: ChatUser(
                  id: other,
                  displayName: otherName,
                  avatarUrl: otherPhoto,
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
                unreadCount: data['unreadCount'] is Map ? ((data['unreadCount'] as Map)[_uid] as num?)?.toInt() ?? 0 : (data['unreadCount'] as num?)?.toInt() ?? 0,
                isArchived: data['isArchived'] == true,
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
  Future<void> markAsUnread(String conversationId) async {
    if (_uid.isEmpty) throw StateError('يرجى تسجيل الدخول');
    final ref = _chats().doc(conversationId);
    final snapshot = await ref.get();
    if (!snapshot.exists) throw StateError('المحادثة غير موجودة');
    final participants = List<String>.from((snapshot.data()?['participants'] as List?)?.map((e) => e.toString()) ?? const []);
    if (!participants.contains(_uid)) throw StateError('ليس لديك صلاحية لهذه المحادثة');
    await ref.update({
      'unreadCount.$_uid': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
