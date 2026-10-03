class GameResult {
  final String gameId; final String? winnerId; final Map<String,int> scores;
  final DateTime? endedAt; final bool timedOut;
  const GameResult({required this.gameId,this.winnerId,this.scores=const {},this.endedAt,this.timedOut=false});
  List<MapEntry<String,int>> get orderedScores => scores.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
}
