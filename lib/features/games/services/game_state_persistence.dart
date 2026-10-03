import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GameStatePersistence {
  GameStatePersistence._();

  static final instance = GameStatePersistence._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _progress(String uid, String gameId) =>
      _db.collection('users').doc(uid).collection('gameProgress').doc(gameId);

  Future<void> save({
    required String gameId,
    required int bestScore,
    required int lastScore,
    Map<String, dynamic> achievements = const {},
    Map<String, dynamic> extra = const {},
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await _progress(uid, gameId).set({
      'bestScore': bestScore,
      'lastScore': lastScore,
      'achievements': achievements,
      ...extra,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<Map<String, dynamic>?> watch(String gameId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _progress(uid, gameId).snapshots().map(
      (snapshot) => snapshot.exists ? snapshot.data() : null,
    );
  }

  Future<Map<String, dynamic>?> read(String gameId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final snapshot = await _progress(uid, gameId).get();
    return snapshot.exists ? snapshot.data() : null;
  }
}
