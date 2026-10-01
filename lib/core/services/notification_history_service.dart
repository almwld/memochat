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

  Future<void> markRead(String id) async {
    final collection = ref;
    if (collection == null) return;
    await collection.doc(id).update({
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }
}
