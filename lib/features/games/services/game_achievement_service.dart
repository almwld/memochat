import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GameAchievementService {
  GameAchievementService._(); static final instance=GameAchievementService._();
  final _db=FirebaseFirestore.instance;
  Future<void> unlock(String achievementId,{Map<String,dynamic> data=const {}}) async {
    final uid=FirebaseAuth.instance.currentUser?.uid;if(uid==null)return;
    await _db.collection('users').doc(uid).collection('achievements').doc(achievementId).set({
      'id':achievementId,...data,'unlockedAt':FieldValue.serverTimestamp(),
    },SetOptions(merge:true));
  }
}