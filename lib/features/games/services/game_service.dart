import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game.dart';
import '../models/game_session.dart';

class GameService {
  GameService._(); static final instance=GameService._();
  final FirebaseFirestore _db=FirebaseFirestore.instance;

  CollectionReference<Map<String,dynamic>> _games(String chatId)=>_db.collection('chats').doc(chatId).collection('games');

  Stream<GameSession?> watchGame(String chatId,String gameId)=>_games(chatId).doc(gameId).snapshots().map((d)=>d.exists?GameSession.fromFirestore(d):null);

  Future<String> createGame({required String chatId,required GameType type,required String uid,GameTimeLimit timeLimit=GameTimeLimit.none}) async {
    final chat = await _db.collection('chats').doc(chatId).get();
    final participants = List<String>.from(chat.data()?['participants'] as List? ?? const []);
    if (participants.length != 2 || !participants.contains(uid)) {
      throw StateError('التحديات المباشرة متاحة بين لاعبين داخل محادثة مباشرة');
    }
    final ref=_games(chatId).doc();
    final now=DateTime.now();
    final session=GameSession(id:ref.id,type:type,players:[uid],status:GameStatus.waiting,timeLimit:timeLimit);
    await ref.set({...session.toFirestore(),'createdAt':Timestamp.fromDate(now),'updatedAt':Timestamp.fromDate(now)});
    return ref.id;
  }

  Future<void> joinGame({required String chatId,required String gameId,required String uid}) async {
    final chat = await _db.collection('chats').doc(chatId).get();
    final participants = List<String>.from(
      chat.data()?['participants'] as List? ?? const [],
    );
    if (!chat.exists || !participants.contains(uid)) {
      throw StateError('لا يمكنك الانضمام إلى لعبة خارج المحادثة.');
    }

    final ref = _games(chatId).doc(gameId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw StateError('جلسة اللعبة غير موجودة.');
      }
      final data = snap.data() ?? <String, dynamic>{};
      final players = List<String>.from(data['players'] as List? ?? const []);
      if (players.contains(uid)) return;
      if (players.length >= 2) {
        throw StateError('اكتملت غرفة اللعبة.');
      }
      final updatedPlayers = [...players, uid];
      tx.update(ref, {
        'players': updatedPlayers,
        'status': updatedPlayers.length >= 2
            ? GameStatus.playing.name
            : GameStatus.waiting.name,
        if (updatedPlayers.length >= 2)
          'startedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> updateGame({required String chatId,required String gameId,required Map<String,dynamic> data}) async {
    await _games(chatId).doc(gameId).update({...data,'updatedAt':FieldValue.serverTimestamp()});
  }

  Future<void> updatePlayerState({
    required String chatId,
    required String gameId,
    required String uid,
    required Map<String, dynamic> state,
    int? score,
    String? currentTurn,
  }) async {
    final ref = _games(chatId).doc(gameId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() ?? <String, dynamic>{};
      final scores = Map<String, dynamic>.from(data['scores'] as Map? ?? const {});
      if (score != null) scores[uid] = score;
      final mergedState = Map<String, dynamic>.from(data['state'] as Map? ?? const {});
      mergedState.addAll(state);
      final update = <String, dynamic>{
        'state': mergedState,
        'scores': scores,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (currentTurn != null) update['currentTurn'] = currentTurn;
      tx.update(ref, update);
    });
  }

  Future<void> endGame({required String chatId,required String gameId,Map<String,int>? scores}) async {
    await _games(chatId).doc(gameId).update({'status':GameStatus.ended.name,'scores':scores??{},'endedAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp()});
  }
}
