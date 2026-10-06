import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'chat_reply_context.dart';
import 'chat_service.dart';
import '../../../core/offline/pending_message_queue.dart';

/// Single authoritative text-message path.
///
/// All text sends go through ChatService so encryption, authorization,
/// idempotency, reply previews, unread counters and the Firestore schema
/// cannot drift between different chat input widgets.
class ReliableMessageService {
  ReliableMessageService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final ReliableMessageService instance = ReliableMessageService._();
  static final PendingMessageQueue _pendingQueue = PendingMessageQueue();

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

    try {
      final id = await ChatService().sendMessage(
        chatId: chatId, text: value, messageId: stableMessageId,
        replyToId: effectiveReplyId, idempotencyKey: 'text_$stableMessageId',
      );
      if (effectiveReplyId != null && effectiveReplyId.isNotEmpty) {
        ChatReplyContext.instance.clear(chatId);
      }
      unawaited(flushPending());
      return id;
    } on FirebaseException catch (e) {
      if (!_isTransientFirestoreError(e.code)) rethrow;
      await _pendingQueue.enqueue(PendingMessage(id: stableMessageId, conversationId: chatId, text: value, createdAt: effectiveTimestamp.toDate()));
      return stableMessageId;
    } on SocketException {
      await _pendingQueue.enqueue(PendingMessage(id: stableMessageId, conversationId: chatId, text: value, createdAt: effectiveTimestamp.toDate()));
      return stableMessageId;
    }
  }

  static bool _isTransientFirestoreError(String code) => code == 'unavailable' || code == 'deadline-exceeded' || code == 'aborted' || code == 'resource-exhausted' || code == 'network-request-failed';

  static Future<void> flushPending() async {
    await _pendingQueue.flush((message) async {
      await ChatService().sendMessage(chatId: message.conversationId, text: message.text, messageId: message.id, idempotencyKey: 'text_${message.id}');
    });
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
