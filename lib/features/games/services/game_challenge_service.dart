import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GameChallengeService {
  GameChallengeService._(); static final instance=GameChallengeService._();
  final _db=FirebaseFirestore.instance;
  Future<String?> create({required String gameId,required String opponentUid}) async {
    final uid=FirebaseAuth.instance.currentUser?.uid;if(uid==null)return null;
    final ref=_db.collection('gameChallenges').doc();
    await ref.set({'id':ref.id,'gameId':gameId,'fromUid':uid,'toUid':opponentUid,'status':'pending','createdAt':FieldValue.serverTimestamp()});
    return ref.id;
  }
  Stream<QuerySnapshot<Map<String,dynamic>>> watchIncoming()=>_db.collection('gameChallenges').where('toUid',isEqualTo:FirebaseAuth.instance.currentUser?.uid).where('status',isEqualTo:'pending').snapshots();
}