import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game.dart';
import '../models/game_session.dart';

class GameService {
  GameService._(); static final instance=GameService._();
  final FirebaseFirestore _db=FirebaseFirestore.instance;

  CollectionReference<Map<String,dynamic>> _games(String chatId)=>_db.collection('chats').doc(chatId).collection('games');

  Stream<GameSession?> watchGame(String chatId,String gameId)=>_games(chatId).doc(gameId).snapshots().map((d)=>d.exists?GameSession.fromFirestore(d):null);

  Future<String> createGame({required String chatId,required GameType type,required String uid,GameTimeLimit timeLimit=GameTimeLimit.none}) async {
    final ref=_games(chatId).doc();
    final now=DateTime.now();
    final session=GameSession(id:ref.id,type:type,players:[uid],status:GameStatus.waiting,timeLimit:timeLimit);
    await ref.set({...session.toFirestore(),'createdAt':Timestamp.fromDate(now),'updatedAt':Timestamp.fromDate(now)});
    return ref.id;
  }

  Future<void> joinGame({required String chatId,required String gameId,required String uid}) async {
    await _games(chatId).doc(gameId).update({'players':FieldValue.arrayUnion([uid]),'status':GameStatus.playing.name,'startedAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp()});
  }

  Future<void> updateGame({required String chatId,required String gameId,required Map<String,dynamic> data}) async {
    await _games(chatId).doc(gameId).update({...data,'updatedAt':FieldValue.serverTimestamp()});
  }

  Future<void> endGame({required String chatId,required String gameId,Map<String,int>? scores}) async {
    await _games(chatId).doc(gameId).update({'status':GameStatus.ended.name,'scores':scores??{},'endedAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp()});
  }
}
