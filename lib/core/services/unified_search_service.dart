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
        .endAt([normalized + '\uf8ff'])
        .limit(limit)
        .get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> messages(
    String chat, {
    int limit = 200,
    DocumentSnapshot? startAfter,
  }) {
    Query<Map<String, dynamic>> query = db
        .collection('chats')
        .doc(chat)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit);
    if (startAfter != null) query = query.startAfterDocument(startAfter);
    return query.get();
  }

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
      return data['isDeleted'] != true && text.contains(normalized);
    }).toList(growable: false);
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> searchMessagesDeep(
    String chat,
    String query, {
    int pageSize = 100,
    int maxPages = 20,
    int maxResults = 100,
  }) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return const [];

    final results = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    DocumentSnapshot? cursor;
    for (var page = 0; page < maxPages && results.length < maxResults; page++) {
      final snapshot =
          await messages(chat, limit: pageSize, startAfter: cursor);
      if (snapshot.docs.isEmpty) break;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final text = data['text']?.toString().toLowerCase() ?? '';
        if (data['isDeleted'] != true && text.contains(normalized)) {
          results.add(doc);
          if (results.length >= maxResults) break;
        }
      }
      cursor = snapshot.docs.last;
      if (snapshot.docs.length < pageSize) break;
    }
    return results;
  }
}
