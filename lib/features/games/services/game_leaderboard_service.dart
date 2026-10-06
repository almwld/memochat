import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GameLeaderboardService {
  GameLeaderboardService._();
  static final instance = GameLeaderboardService._();
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> submitScore({required String gameId, required int score, int? durationSeconds, bool won = false}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final gameRef = _db.collection('gameLeaderboard').doc(gameId).collection('scores').doc(uid);
    final globalRef = _db.collection('globalLeaderboard').doc(uid);
    await _db.runTransaction((tx) async {
      final gameSnap = await tx.get(gameRef);
      final globalSnap = await tx.get(globalRef);
      final current = gameSnap.data() ?? const <String, dynamic>{};
      final previousBest = (current['bestScore'] as num?)?.toInt() ?? 0;
      final gamesPlayed = (current['gamesPlayed'] as num?)?.toInt() ?? 0;
      final nextBest = score > previousBest ? score : previousBest;
      final profile = _auth.currentUser;
      tx.set(gameRef, {
        'uid': uid,
        'bestScore': nextBest,
        'score': nextBest,
        'lastScore': score,
        'gamesPlayed': gamesPlayed + 1,
        'wins': ((current['wins'] as num?)?.toInt() ?? 0) + (won ? 1 : 0),
        'durationSeconds': durationSeconds,
        'displayName': profile?.displayName ?? 'لاعب',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final global = globalSnap.data() ?? const <String, dynamic>{};
      tx.set(globalRef, {
        'uid': uid,
        'displayName': profile?.displayName ?? 'لاعب',
        'totalPoints': ((global['totalPoints'] as num?)?.toInt() ?? 0) + score,
        'bestScore': maxInt((global['bestScore'] as num?)?.toInt() ?? 0, score),
        'gamesPlayed': ((global['gamesPlayed'] as num?)?.toInt() ?? 0) + 1,
        'wins': ((global['wins'] as num?)?.toInt() ?? 0) + (won ? 1 : 0),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchBest(String gameId, {int limit = 20}) => _db.collection('gameLeaderboard').doc(gameId).collection('scores').orderBy('bestScore', descending: true).limit(limit).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchGlobal({int limit = 50}) => _db.collection('globalLeaderboard').orderBy('totalPoints', descending: true).limit(limit).snapshots();

  int maxInt(int a, int b) => a > b ? a : b;
}
