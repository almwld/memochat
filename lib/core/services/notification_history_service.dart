import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationHistoryService {
  final FirebaseFirestore db;
  final FirebaseAuth auth;

  NotificationHistoryService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  })  : db = firestore ?? FirebaseFirestore.instance,
        auth = firebaseAuth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>>? get ref {
    final uid = auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return null;
    return db.collection('users').doc(uid).collection('notificationHistory');
  }

  Future<void> add(
    String type,
    String title,
    String body, {
    String? route,
    Map<String, dynamic>? data,
    String? id,
  }) async {
    final collection = ref;
    if (collection == null) return;
    final document = id == null ? collection.doc() : collection.doc(id);
    await db.runTransaction((transaction) async {
      final existing = await transaction.get(document);
      // A push may arrive on multiple devices or be retried by FCM. Never
      // reset a notification that the user already read back to unread.
      if (existing.exists) return;
      transaction.set(document, {
        'type': type,
        'title': title,
        'body': body,
        'route': route,
        'data': data ?? <String, dynamic>{},
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watch({int limit = 100}) {
    final collection = ref;
    if (collection == null) return const Stream.empty();
    return collection
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> recent({
    int limit = 100,
  }) async {
    final collection = ref;
    if (collection == null) return const [];
    final snapshot = await collection
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs;
  }

  Future<void> _markCanonicalRead(String id) async {
    // The local history is the UI source, while the top-level server record
    // drives cross-device notification state. Older/local-only notifications
    // may not have a canonical record, so this update is intentionally best effort.
    try {
      await db.collection('notifications').doc(id).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> markRead(String id) async {
    final collection = ref;
    if (collection == null) return;
    await collection.doc(id).update({
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
    });
    await _markCanonicalRead(id);
  }

  Future<void> markAllRead() async {
    final collection = ref;
    if (collection == null) return;
    while (true) {
      final snapshot =
          await collection.where('read', isEqualTo: false).limit(100).get();
      if (snapshot.docs.isEmpty) break;
      final batch = db.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      await Future.wait(snapshot.docs.map((doc) => _markCanonicalRead(doc.id)));
      if (snapshot.docs.length < 100) break;
    }
  }
}
