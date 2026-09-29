import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_reply_context.dart';
import '../models/message_model.dart';

/// Reliable text path: message + chat preview + unread counter in one batch.
class ReliableMessageService {
  ReliableMessageService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<String> sendText({
    required String chatId,
    required String text,
    String? replyToId,
    Timestamp? clientTimestamp,
    String? messageId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('يجب تسجيل الدخول');
    final value = text.trim();
    if (value.isEmpty) throw Exception('نص الرسالة فارغ');

    final chatRef = _db.collection('chats').doc(chatId);
    final chatSnapshot = await chatRef.get();
    if (!chatSnapshot.exists) throw Exception('المحادثة غير موجودة');
    final chat = chatSnapshot.data() ?? <String, dynamic>{};
    final participants = List<String>.from(chat['participants'] ?? const <String>[]);
    if (!participants.contains(user.uid)) throw Exception('ليس لديك صلاحية لهذه المحادثة');

    final reply = replyToId == null || replyToId.isEmpty
        ? ChatReplyContext.instance.forChat(chatId)
        : null;
    final effectiveReplyId = replyToId ?? reply?.id;
    Map<String, dynamic>? replyPreview;
    final targetId = effectiveReplyId;
    if (targetId != null && targetId.isNotEmpty) {
      final target = await chatRef.collection('messages').doc(targetId).get();
      if (target.exists) {
        final d = target.data() ?? <String, dynamic>{};
        replyPreview = {
          'id': target.id,
          'senderId': d['senderId']?.toString() ?? '',
          'senderName': d['senderName']?.toString() ?? 'مستخدم',
          'text': d['text']?.toString() ?? _attachmentPreview(d),
          'type': d['type']?.toString() ?? 'text',
        };
      }
    }

    final effectiveClientTimestamp = clientTimestamp ?? Timestamp.now();
    final messageRef = chatRef.collection('messages').doc(
      messageId ?? 'msg_${effectiveClientTimestamp.microsecondsSinceEpoch}',
    );
    final batch = _db.batch();
    batch.set(messageRef, {
      'chatId': chatId,
      'senderId': user.uid,
      'senderName': user.displayName ?? 'مستخدم',
      'senderPhotoUrl': user.photoURL,
      'text': value,
      'type': 'text',
      'timestamp': FieldValue.serverTimestamp(),
      'clientTimestamp': effectiveClientTimestamp,
      'status': MessageStatus.sent.name,
      'isRead': false,
      'isDelivered': false,
      'deliveredAt': null,
      'isDeleted': false,
      'isEdited': false,
      'replyToId': effectiveReplyId,
      'replyPreview': replyPreview,
      'reactions': <String, dynamic>{},
    });
    final chatUpdate = <String, dynamic>{
      'lastMessage': value,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    for (final participantId in participants) {
      if (participantId != user.uid && participantId.isNotEmpty) {
        chatUpdate['unreadCount.$participantId'] = FieldValue.increment(1);
      }
    }
    batch.update(chatRef, chatUpdate);
    await batch.commit();
    if (effectiveReplyId != null) ChatReplyContext.instance.clear(chatId);
    return messageRef.id;
  }

  static String _attachmentPreview(Map<String, dynamic> d) {
    switch (d['type']?.toString()) {
      case 'image': return '📷 صورة';
      case 'video': return '🎬 فيديو';
      case 'audio': return '🎤 رسالة صوتية';
      case 'file': return '📎 ملف';
      case 'location': return '📍 موقع';
      default: return 'مرفق';
    }
  }
}