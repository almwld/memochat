import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RelationshipService {
  final FirebaseFirestore db;
  final FirebaseAuth auth;

  RelationshipService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  })  : db = firestore ?? FirebaseFirestore.instance,
        auth = firebaseAuth ?? FirebaseAuth.instance;

  DocumentReference<Map<String, dynamic>> ref(String uid) {
    final me = auth.currentUser?.uid;
    if (me == null || me.isEmpty) throw StateError('Authentication required');
    final target = uid.trim();
    if (target.isEmpty || target == me) {
      throw ArgumentError('Invalid relationship target');
    }
    return db.collection('users').doc(me).collection('relationships').doc(target);
  }

  Future<void> set(
    String uid, {
    bool? blocked,
    bool? muted,
    bool? pinned,
  }) async {
    final target = uid.trim();
    await ref(target).set({
      'uid': target,
      if (blocked != null) 'blocked': blocked,
      if (muted != null) 'muted': muted,
      if (pinned != null) 'pinned': pinned,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setFriendState(
    String uid, {
    required bool friend,
  }) async {
    await ref(uid).set({
      'uid': uid,
      'friend': friend,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> get(String uid) async {
    final snapshot = await ref(uid).get();
    return snapshot.exists ? snapshot.data() : null;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watch(String uid) =>
      ref(uid).snapshots();
}
