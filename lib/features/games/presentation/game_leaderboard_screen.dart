import 'package:flutter/material.dart';
import '../services/game_leaderboard_service.dart';

class GameLeaderboardScreen extends StatefulWidget {
  final String gameId;
  final String title;
  const GameLeaderboardScreen({
    super.key,
    required this.gameId,
    required this.title,
  });

  @override
  State<GameLeaderboardScreen> createState() => _GameLeaderboardScreenState();
}

class _GameLeaderboardScreenState extends State<GameLeaderboardScreen> {
  bool _global = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('العالمية'), icon: Icon(Icons.public_rounded)),
                ButtonSegment(value: false, label: Text('هذه اللعبة'), icon: Icon(Icons.sports_esports_rounded)),
              ],
              selected: {_global},
              onSelectionChanged: (v) => setState(() => _global = v.first),
            ),
          ),
          _MyStatsCard(),
          Expanded(
            child: _global ? _globalBoard() : _gameBoard(),
          ),
        ],
      ),
    );
  }

  Widget _MyStatsCard() {
    return StreamBuilder(
      stream: GameLeaderboardService.instance.watchMyStats(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final total = (data?['totalScore'] as num?)?.toInt() ?? 0;
        final games = (data?['gamesPlayed'] as num?)?.toInt() ?? 0;
        final wins = (data?['wins'] as num?)?.toInt() ?? 0;
        final best = (data?['bestScore'] as num?)?.toInt() ?? 0;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    child: Icon(Icons.person_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'إحصائياتك',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  _Stat('النقاط', '$total'),
                  _Stat('الألعاب', '$games'),
                  _Stat('الانتصارات', '$wins'),
                  _Stat('الأفضل', '$best'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _Stat(String label, String value) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 8),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
            Text(label, style: const TextStyle(fontSize: 9)),
          ],
        ),
      );

  Widget _globalBoard() => StreamBuilder(
        stream: GameLeaderboardService.instance.watchGlobal(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('تعذر تحميل لوحة الصدارة'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('لا توجد نتائج بعد'));
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data();
              final score = (d['totalScore'] as num?)?.toInt() ?? 0;
              final games = (d['gamesPlayed'] as num?)?.toInt() ?? 0;
              final wins = (d['wins'] as num?)?.toInt() ?? 0;
              return _PlayerTile(
                rank: i + 1,
                name: d['displayName']?.toString() ?? 'لاعب',
                photoUrl: d['photoUrl']?.toString(),
                score: score,
                subtitle: '$games لعبة • $wins انتصار',
              );
            },
          );
        },
      );

  Widget _gameBoard() => StreamBuilder(
        stream: GameLeaderboardService.instance.watchBest(widget.gameId),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('تعذر تحميل نتائج اللعبة'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('لا توجد نتائج بعد'));
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data();
              return _PlayerTile(
                rank: i + 1,
                name: d['displayName']?.toString() ?? 'لاعب',
                photoUrl: d['photoUrl']?.toString(),
                score: (d['score'] as num?)?.toInt() ?? 0,
                subtitle: 'أفضل نتيجة في هذه اللعبة',
              );
            },
          );
        },
      );
}

class _PlayerTile extends StatelessWidget {
  final int rank;
  final String name;
  final String? photoUrl;
  final int score;
  final String subtitle;

  const _PlayerTile({
    required this.rank,
    required this.name,
    required this.photoUrl,
    required this.score,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundImage: photoUrl != null && photoUrl!.isNotEmpty ? NetworkImage(photoUrl!) : null,
            child: photoUrl == null || photoUrl!.isEmpty ? Text('$rank') : null,
          ),
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(subtitle),
          trailing: Text(
            '$score',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
}
