import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameService {
  GameService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  Future<int> bestScore(String gameId) async {
    final prefs = await SharedPreferences.getInstance();
    var best = prefs.getInt('game.best.$gameId') ?? 0;
    final user = _auth.currentUser;
    if (user == null) return best;
    try {
      final snap = await _db.collection('users').doc(user.uid).collection('gameScores').doc(gameId).get();
      final cloud = (snap.data()?['bestScore'] as num?)?.toInt() ?? 0;
      if (cloud > best) {
        best = cloud;
        await prefs.setInt('game.best.$gameId', best);
      }
    } catch (_) {}
    return best;
  }

  Future<void> saveScore({required String gameId, required int score, required int level}) async {
    final prefs = await SharedPreferences.getInstance();
    final localBest = prefs.getInt('game.best.$gameId') ?? 0;
    final best = score > localBest ? score : localBest;
    await prefs.setInt('game.best.$gameId', best);
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _db.collection('users').doc(user.uid).collection('gameScores').doc(gameId).set({
        'bestScore': best,
        'lastScore': score,
        'level': level,
        'playedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}
