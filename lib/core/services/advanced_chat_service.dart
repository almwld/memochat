import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdvancedChatService {
  final FirebaseFirestore db;
  final FirebaseAuth auth;

  AdvancedChatService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  })  : db = firestore ?? FirebaseFirestore.instance,
        auth = firebaseAuth ?? FirebaseAuth.instance;

  Future<void> setState(
    String chat,
    String message,
    String field,
    dynamic value,
  ) async {
    final uid = auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Authentication required');
    }
    const allowed = {
      'deliveredAt',
      'readAt',
      'pinned',
      'editedAt',
      'deletedForEveryone',
    };
    if (!allowed.contains(field)) {
      throw ArgumentError('Unsupported state');
    }

    final chatRef = db.collection('chats').doc(chat);
    final chatSnap = await chatRef.get();
    if (!chatSnap.exists) throw StateError('Chat not found');
    final participants = List<String>.from(
      chatSnap.data()?['participants'] as List? ?? const [],
    );
    if (!participants.contains(uid)) {
      throw StateError('Not a chat participant');
    }

    await chatRef.collection('messages').doc(message).update({
      field: value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markDelivered(String chat, String message) =>
      setState(chat, message, 'deliveredAt', FieldValue.serverTimestamp());

  Future<void> markRead(String chat, String message) =>
      setState(chat, message, 'readAt', FieldValue.serverTimestamp());

  Future<void> setPinned(
    String chat,
    String message, {
    required bool value,
  }) =>
      setState(chat, message, 'pinned', value);
}
