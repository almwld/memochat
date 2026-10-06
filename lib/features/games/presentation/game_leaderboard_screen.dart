import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/game_leaderboard_service.dart';

class GameLeaderboardScreen extends StatelessWidget {
  const GameLeaderboardScreen({super.key, required this.gameId, required this.title});
  final String gameId;
  final String title;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), bottom: const TabBar(tabs: [Tab(text: 'اللعبة'), Tab(text: 'العالمية')])),
        body: TabBarView(children: [
          _LeaderboardList(stream: GameLeaderboardService.instance.watchBest(gameId), scoreField: 'bestScore', emptyLabel: 'لا توجد نتائج لهذه اللعبة بعد.'),
          _LeaderboardList(stream: GameLeaderboardService.instance.watchGlobal(), scoreField: 'totalPoints', emptyLabel: 'ابدأ اللعب لتظهر في اللوحة العالمية.'),
        ]),
      ),
    );
  }
}

class _LeaderboardList extends StatelessWidget {
  const _LeaderboardList({required this.stream, required this.scoreField, required this.emptyLabel});
  final Stream<dynamic> stream;
  final String scoreField;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<dynamic>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('تعذر تحميل لوحة الصدارة الآن\n${snapshot.error}', textAlign: TextAlign.center)));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data.docs;
        if (docs.isEmpty) return Center(child: Text(emptyLabel));
        final top = docs.take(3).toList();
        return RefreshIndicator(
          onRefresh: () async => Future<void>.delayed(const Duration(milliseconds: 250)),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 40), children: [
            _Podium(docs: top, scoreField: scoreField),
            const SizedBox(height: 20),
            ...docs.asMap().entries.map((entry) {
              final index = entry.key;
              final data = entry.value.data() as Map<String, dynamic>;
              final uid = data['uid']?.toString() ?? entry.value.id;
              final score = (data[scoreField] as num?)?.toInt() ?? 0;
              final isMe = uid == currentUid;
              return Padding(padding: const EdgeInsets.only(bottom: 8), child: Card(color: isMe ? Theme.of(context).colorScheme.primaryContainer : null, child: ListTile(leading: CircleAvatar(backgroundColor: isMe ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest, child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w900))), title: Text(isMe ? 'أنت' : (data['displayName']?.toString() ?? 'لاعب'), style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${data['gamesPlayed'] ?? 0} جولات • ${data['wins'] ?? 0} انتصارات'), trailing: Text('$score', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900))));
            }),
          ]),
        );
      },
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.docs, required this.scoreField});
  final List<dynamic> docs;
  final String scoreField;
  @override
  Widget build(BuildContext context) {
    final colors = [const Color(0xFFFFB020), const Color(0xFF9AA7B6), const Color(0xFFB97848)];
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(3, (index) {
      if (index >= docs.length) return const Expanded(child: SizedBox(height: 120));
      final data = docs[index].data() as Map<String, dynamic>;
      final score = (data[scoreField] as num?)?.toInt() ?? 0;
      final height = 92.0 - index * 15;
      return Expanded(child: Column(children: [Icon(index == 0 ? Icons.workspace_premium_rounded : Icons.stars_rounded, color: colors[index], size: 30), const SizedBox(height: 4), Text(data['displayName']?.toString() ?? 'لاعب', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 5), Container(height: height, margin: const EdgeInsets.symmetric(horizontal: 5), decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), gradient: LinearGradient(colors: [colors[index].withOpacity(.85), colors[index].withOpacity(.28)], begin: Alignment.topCenter, end: Alignment.bottomCenter)), child: Center(child: Text('$score', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))))]));
    }));
  }
}
