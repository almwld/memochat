import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreAuthorization {
  final FirebaseAuth auth;

  FirestoreAuthorization({FirebaseAuth? firebaseAuth})
      : auth = firebaseAuth ?? FirebaseAuth.instance;

  String get uid => auth.currentUser?.uid ??
      (throw StateError('Authentication required'));

  static bool ownsForUid(String uid, String owner) => owner == uid;

  static bool participantForUid(String uid, Map<String, dynamic> data) =>
      ((data['participantIds'] as List?) ?? const []).contains(uid) ||
      ((data['participants'] as List?) ?? const []).contains(uid);

  bool owns(String owner) => ownsForUid(uid, owner);

  bool participant(Map<String, dynamic> data) =>
      participantForUid(uid, data);

  Future<bool> canChat(FirebaseFirestore db, String id) async {
    final d = await db.collection('chats').doc(id).get();
    return d.exists && participant(d.data() ?? {});
  }
}
