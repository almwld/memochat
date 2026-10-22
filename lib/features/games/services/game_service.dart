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
    final session=GameSession(id:ref.id,type:type,players:[uid],status:GameStatus.waiting,scores:{uid:0},timeLimit:timeLimit);
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
        if (updatedPlayers.length >= 2) ...{
          'startedAt': FieldValue.serverTimestamp(),
          'currentTurn': updatedPlayers.first,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> updateGame({required String chatId,required String gameId,required Map<String,dynamic> data}) async {
    await _games(chatId).doc(gameId).update({...data,'updatedAt':FieldValue.serverTimestamp()});
  }

  /// Applies a single XO move atomically so two clients cannot occupy the
  /// same cell or both move from a stale turn snapshot.
  Future<Map<String, dynamic>> submitXoMove({
    required String chatId,
    required String gameId,
    required String uid,
    required int cell,
    required int score,
  }) async {
    if (cell < 0 || cell >= 9) throw RangeError.index(cell, List<int>.filled(9, 0));
    final ref = _games(chatId).doc(gameId);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('جلسة اللعبة غير موجودة.');
      final data = snap.data() ?? <String, dynamic>{};
      final players = List<String>.from(data['players'] as List? ?? const []);
      if (players.length != 2 || !players.contains(uid)) {
        throw StateError('يجب أن يكون اللاعب ضمن جلسة XO نشطة.');
      }
      if (data['status']?.toString() != GameStatus.playing.name) {
        throw StateError('جلسة XO ليست قيد اللعب.');
      }
      if (data['currentTurn']?.toString() != uid) {
        throw StateError('ليس دورك؛ تم تحديث دور اللاعب الآخر.');
      }
      final state = Map<String, dynamic>.from(data['state'] as Map? ?? const {});
      final rawBoard = state['xoBoard'];
      final board = rawBoard is List && rawBoard.length == 9
          ? rawBoard.map((v) => v is num ? v.toInt() : 0).toList()
          : List<int>.filled(9, 0);
      if (board[cell] != 0) throw StateError('هذه الخانة حُجزت بالفعل.');
      final winnerBefore = (state['xoWinner'] as num?)?.toInt() ?? 0;
      if (winnerBefore != 0) throw StateError('انتهت الجولة؛ ابدأ جولة جديدة.');
      final marker = players.indexOf(uid) + 1;
      board[cell] = marker;
      var winner = 0;
      const lines = <List<int>>[
        [0,1,2],[3,4,5],[6,7,8],
        [0,3,6],[1,4,7],[2,5,8],
        [0,4,8],[2,4,6],
      ];
      for (final line in lines) {
        if (board[line[0]] != 0 &&
            board[line[0]] == board[line[1]] &&
            board[line[1]] == board[line[2]]) {
          winner = board[line[0]];
          break;
        }
      }
      if (winner == 0 && board.every((v) => v != 0)) winner = 3;
      final round = ((state['round'] as num?)?.toInt() ?? 0) + 1;
      state.addAll({'xoBoard': board, 'xoWinner': winner, 'round': round, 'gameType': GameType.xo.name});
      final scores = Map<String, dynamic>.from(data['scores'] as Map? ?? const {});
      scores[uid] = score < 0 ? 0 : score;
      final nextTurn = winner == 0 ? players.firstWhere((player) => player != uid) : uid;
      tx.update(ref, {
        'state': state,
        'scores': scores,
        'currentTurn': nextTurn,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return <String, dynamic>{
        'board': board,
        'winner': winner,
        'round': round,
        'currentTurn': nextTurn,
      };
    });
  }

  /// Starts a rematch from a terminal XO board. The transaction prevents
  /// both players from resetting the same round over one another.
  Future<Map<String, dynamic>> resetXoGame({
    required String chatId,
    required String gameId,
    required String uid,
  }) async {
    final ref = _games(chatId).doc(gameId);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('جلسة اللعبة غير موجودة.');
      final data = snap.data() ?? <String, dynamic>{};
      final players = List<String>.from(data['players'] as List? ?? const []);
      if (!players.contains(uid)) throw StateError('لست لاعبًا في هذه الجلسة.');
      if (data['status']?.toString() != GameStatus.playing.name) {
        throw StateError('جلسة XO ليست قيد اللعب.');
      }
      final state = Map<String, dynamic>.from(data['state'] as Map? ?? const {});
      final winner = (state['xoWinner'] as num?)?.toInt() ?? 0;
      if (winner == 0) throw StateError('لا يمكن إعادة الجولة قبل انتهائها.');
      final board = List<int>.filled(9, 0);
      final round = ((state['round'] as num?)?.toInt() ?? 0) + 1;
      state.addAll({'xoBoard': board, 'xoWinner': 0, 'round': round, 'gameType': GameType.xo.name});
      tx.update(ref, {
        'state': state,
        'currentTurn': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return <String, dynamic>{'board': board, 'winner': 0, 'round': round, 'currentTurn': uid};
    });
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
      final players = List<String>.from(data['players'] as List? ?? const []);
      if (!players.contains(uid)) {
        throw StateError('لا يمكنك تحديث لعبة لست لاعبًا فيها.');
      }
      if (data['status']?.toString() != GameStatus.playing.name) {
        throw StateError('اللعبة ليست في حالة لعب.');
      }
      final startedRaw = data['startedAt'];
      final startedAt = startedRaw is Timestamp ? startedRaw.toDate() : null;
      final limitName = data['timeLimit']?.toString();
      final limit = GameTimeLimit.values.firstWhere(
        (e) => e.name == limitName,
        orElse: () => GameTimeLimit.none,
      );
      if (startedAt != null && limit.duration != null &&
          DateTime.now().difference(startedAt) >= limit.duration!) {
        tx.update(ref, {
          'status': GameStatus.ended.name,
          'endedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }
      final scores = Map<String, dynamic>.from(data['scores'] as Map? ?? const {});
      if (score != null) scores[uid] = score < 0 ? 0 : score;
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
