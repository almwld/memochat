import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GameLeaderboardService {
  GameLeaderboardService._(); static final instance=GameLeaderboardService._();
  final _db=FirebaseFirestore.instance;
  Future<void> submitScore({required String gameId,required int score}) async {
    final uid=FirebaseAuth.instance.currentUser?.uid;if(uid==null)return;
    await _db.collection('gameLeaderboard').doc(gameId).collection('scores').doc(uid).set({
      'uid':uid,'score':score,'updatedAt':FieldValue.serverTimestamp(),
    },SetOptions(merge:true));
  }
  Stream<QuerySnapshot<Map<String,dynamic>>> watchBest(String gameId,{int limit=20})=>_db.collection('gameLeaderboard').doc(gameId).collection('scores').orderBy('score',descending:true).limit(limit).snapshots();
}