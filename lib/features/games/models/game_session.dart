import 'package:cloud_firestore/cloud_firestore.dart';
import 'game.dart';

class GameSession {
  final String id; final GameType type; final List<String> players;
  final Map<String, dynamic> state; final String? currentTurn;
  final Map<String, int> scores; final DateTime? startedAt; final DateTime? endedAt;
  final GameStatus status; final GameTimeLimit timeLimit;
  const GameSession({required this.id, required this.type, required this.players, this.state=const {}, this.currentTurn, this.scores=const {}, this.startedAt, this.endedAt, this.status=GameStatus.waiting, this.timeLimit=GameTimeLimit.none});

  factory GameSession.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data=doc.data() ?? const <String,dynamic>{}; final scores=<String,int>{};
    final raw=data['scores']; if(raw is Map) raw.forEach((k,v){scores[k.toString()]=(v as num?)?.toInt()??0;});
    return GameSession(id:doc.id, type:GameType.values.firstWhere((e)=>e.name==data['type'],orElse:()=>GameType.xo), players:List<String>.from(data['players'] as List? ?? const []), state:Map<String,dynamic>.from(data['state'] as Map? ?? const {}), currentTurn:data['currentTurn']?.toString(), scores:scores, startedAt:(data['startedAt'] as Timestamp?)?.toDate(), endedAt:(data['endedAt'] as Timestamp?)?.toDate(), status:GameStatus.values.firstWhere((e)=>e.name==data['status'],orElse:()=>GameStatus.waiting), timeLimit:GameTimeLimit.values.firstWhere((e)=>e.name==data['timeLimit'],orElse:()=>GameTimeLimit.none));
  }

  Map<String,dynamic> toFirestore()=>{'type':type.name,'players':players,'state':state,'currentTurn':currentTurn,'scores':scores,'startedAt':startedAt==null?null:Timestamp.fromDate(startedAt!),'endedAt':endedAt==null?null:Timestamp.fromDate(endedAt!),'status':status.name,'timeLimit':timeLimit.name};
}
