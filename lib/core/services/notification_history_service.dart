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
    await document.set({
      'type': type,
      'title': title,
      'body': body,
      'route': route,
      'data': data ?? <String, dynamic>{},
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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

  Future<void> markRead(String id) async {
    final collection = ref;
    if (collection == null) return;
    await collection.doc(id).update({
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAllRead() async {
    final collection = ref;
    if (collection == null) return;
    final snapshot =
        await collection.where('read', isEqualTo: false).limit(100).get();
    final batch = db.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    if (snapshot.docs.isNotEmpty) await batch.commit();
  }
}
