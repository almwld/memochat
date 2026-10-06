import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Canonical delivery acknowledgement path adapted from the proven Sehatak
/// chat transport while preserving MemoChat's E2EE message envelope.
class MessageDeliveryService {
  MessageDeliveryService._();
  static final instance = MessageDeliveryService._();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final Set<String> _acknowledged = <String>{};

  Future<void> acknowledgeDelivered({
    required String chatId,
    required Iterable<String> messageIds,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty || chatId.isEmpty) return;

    final ids = messageIds
        .where((id) => id.isNotEmpty && !_acknowledged.contains(chatId + '/' + id))
        .toSet();
    if (ids.isEmpty) return;

    final chat = await _firestore.collection('chats').doc(chatId).get();
    if (!chat.exists) return;
    final participants = List<String>.from(chat.data()?['participants'] ?? const <String>[]);
    if (!participants.contains(uid)) return;

    final refs = ids.map((id) => _firestore.collection('chats').doc(chatId).collection('messages').doc(id)).toList();
    final snapshots = await Future.wait(refs.map((ref) => ref.get()));
    final batch = _firestore.batch();
    var changed = 0;

    for (var i = 0; i < snapshots.length; i++) {
      final snapshot = snapshots[i];
      if (!snapshot.exists) continue;
      final data = snapshot.data() ?? const <String, dynamic>{};
      if (data['senderId']?.toString() == uid) continue;
      if (data['isDelivered'] == true) {
        _acknowledged.add(chatId + '/' + snapshot.id);
        continue;
      }
      batch.update(refs[i], {
        'isDelivered': true,
        'status': 'delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
      });
      _acknowledged.add(chatId + '/' + snapshot.id);
      changed++;
    }

    if (changed > 0) await batch.commit();
  }

  void clearChat(String chatId) {
    _acknowledged.removeWhere((key) => key.startsWith(chatId + '/'));
  }
}
