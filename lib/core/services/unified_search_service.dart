import 'package:cloud_firestore/cloud_firestore.dart';

class UnifiedSearchService {
  final FirebaseFirestore db;

  UnifiedSearchService({FirebaseFirestore? firestore})
      : db = firestore ?? FirebaseFirestore.instance;

  Future<QuerySnapshot<Map<String, dynamic>>> users(
    String q, {
    int limit = 25,
  }) {
    final normalized = q.trim().toLowerCase();
    return db
        .collection('users')
        .orderBy('usernameLower')
        .startAt([normalized])
        .endAt(['$normalized\uf8ff'])
        .limit(limit)
        .get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> messages(
    String chat, {
    int limit = 200,
  }) =>
      db
          .collection('chats')
          .doc(chat)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

  /// Searches message text within the bounded recent-message window.
  /// Firestore does not provide a native contains query, so filtering is
  /// intentionally performed after the authorized chat query.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> searchMessages(
    String chat,
    String query, {
    int limit = 200,
  }) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return const [];
    final snapshot = await messages(chat, limit: limit);
    return snapshot.docs.where((doc) {
      final data = doc.data();
      final text = data['text']?.toString().toLowerCase() ?? '';
      return text.contains(normalized) && data['isDeleted'] != true;
    }).toList(growable: false);
  }
}
