import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GameLeaderboardService {
  GameLeaderboardService._();
  static final instance = GameLeaderboardService._();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> submitScore({
    required String gameId,
    required int score,
    bool won = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final safeGameId = gameId.trim().isEmpty ? 'unknown' : gameId.trim();
    final scoreRef = _db
        .collection('gameLeaderboard')
        .doc(safeGameId)
        .collection('scores')
        .doc(uid);
    final playerRef = _db.collection('gameLeaderboard').doc('global').collection('players').doc(uid);

    await _db.runTransaction((tx) async {
      final previousScoreSnap = await tx.get(scoreRef);
      final previousPlayerSnap = await tx.get(playerRef);
      final previousScore = (previousScoreSnap.data()?['score'] as num?)?.toInt() ?? 0;
      final previousGames = (previousPlayerSnap.data()?['gamesPlayed'] as num?)?.toInt() ?? 0;
      final previousWins = (previousPlayerSnap.data()?['wins'] as num?)?.toInt() ?? 0;
      final previousTotal = (previousPlayerSnap.data()?['totalScore'] as num?)?.toInt() ?? 0;
      final previousBest = (previousPlayerSnap.data()?['bestScore'] as num?)?.toInt() ?? 0;
      final previousStreak = (previousPlayerSnap.data()?['bestStreak'] as num?)?.toInt() ?? 0;

      tx.set(scoreRef, {
        'uid': uid,
        'score': score > previousScore ? score : previousScore,
        'lastScore': score,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(playerRef, {
        'uid': uid,
        'displayName': user.displayName?.trim().isNotEmpty == true ? user.displayName!.trim() : 'لاعب',
        'photoUrl': user.photoURL,
        'gamesPlayed': previousGames + 1,
        'wins': previousWins + (won ? 1 : 0),
        'totalScore': previousTotal + score,
        'bestScore': score > previousBest ? score : previousBest,
        'bestStreak': previousStreak,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchBest(
    String gameId, {
    int limit = 20,
  }) =>
      _db
          .collection('gameLeaderboard')
          .doc(gameId)
          .collection('scores')
          .orderBy('score', descending: true)
          .limit(limit)
          .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchGlobal({
    int limit = 50,
  }) =>
      _db
          .collection('gameLeaderboard')
          .doc('global')
          .collection('players')
          .orderBy('totalScore', descending: true)
          .limit(limit)
          .snapshots();

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchMyStats() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }
    return _db
        .collection('gameLeaderboard')
        .doc('global')
        .collection('players')
        .doc(uid)
        .snapshots();
  }
}
