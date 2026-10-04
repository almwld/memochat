import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'chat_reply_context.dart';
import 'chat_service.dart';

/// Single authoritative text-message path.
///
/// All text sends go through ChatService so encryption, authorization,
/// idempotency, reply previews, unread counters and the Firestore schema
/// cannot drift between different chat input widgets.
class ReliableMessageService {
  ReliableMessageService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final ReliableMessageService instance = ReliableMessageService._();

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

    final effectiveTimestamp = clientTimestamp ?? Timestamp.now();
    final stableMessageId = messageId?.trim().isNotEmpty == true
        ? messageId!.trim()
        : 'msg_${effectiveTimestamp.microsecondsSinceEpoch}';

    final reply = replyToId == null || replyToId.trim().isEmpty
        ? ChatReplyContext.instance.forChat(chatId)
        : null;
    final effectiveReplyId = replyToId?.trim().isNotEmpty == true
        ? replyToId!.trim()
        : reply?.id;

    final id = await ChatService().sendMessage(
      chatId: chatId,
      text: value,
      messageId: stableMessageId,
      replyToId: effectiveReplyId,
      idempotencyKey: 'text_$stableMessageId',
    );

    if (effectiveReplyId != null && effectiveReplyId.isNotEmpty) {
      ChatReplyContext.instance.clear(chatId);
    }
    return id;
  }

  Future<void> acknowledgeDelivered({
    required String chatId,
    required List<String> messageIds,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || messageIds.isEmpty) return;

    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    for (final id in messageIds) {
      final ref = db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(id);
      batch.update(ref, {
        'isDelivered': true,
        'deliveredAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}
