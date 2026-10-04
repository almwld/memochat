import 'package:flutter/material.dart';
import '../data/game_catalog.dart';
import 'game_play_screen.dart';

class GamesHubScreen extends StatefulWidget {
  const GamesHubScreen({super.key});
  @override State<GamesHubScreen> createState() => _GamesHubScreenState();
}

class _GamesHubScreenState extends State<GamesHubScreen> {
  String _category = 'الكل';
  String _query = '';

  List<GameDefinition> get _games {
    final q = _query.trim().toLowerCase();
    return gameCatalog.where((game) => (_category == 'الكل' || game.category == _category) && (q.isEmpty || game.title.toLowerCase().contains(q) || game.subtitle.toLowerCase().contains(q))).toList();
  }

  void _open(GameDefinition game) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GamePlayScreen(game: game)));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final categories = ['الكل', ...{...gameCatalog.map((game) => game.category)}];
    final featured = gameCatalog.where((game) => game.featured).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('ألعاب MemoChat', style: TextStyle(fontWeight: FontWeight.w900)), actions: [IconButton(onPressed: () => _showInfo(context), icon: const Icon(Icons.info_outline_rounded), tooltip: 'عن الألعاب')]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        children: [
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), gradient: LinearGradient(colors: [scheme.primary, Color.lerp(scheme.primary, const Color(0xFF143E60), .55)!], begin: Alignment.topRight, end: Alignment.bottomLeft), boxShadow: [BoxShadow(color: scheme.primary.withOpacity(.25), blurRadius: 22, offset: const Offset(0, 12))]), child: Row(children: [Container(width: 62, height: 62, decoration: BoxDecoration(color: Colors.white.withOpacity(.18), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.sports_esports_rounded, color: Colors.white, size: 34)), const SizedBox(width: 14), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('وقت اللعب', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)), SizedBox(height: 5), Text('تحديات قصيرة، نقاط جديدة، ومتعة داخل MemoChat.', style: TextStyle(color: Colors.white70, height: 1.4))]))])),
          const SizedBox(height: 16),
          TextField(onChanged: (value) => setState(() => _query = value), decoration: InputDecoration(hintText: 'ابحث في الألعاب...', prefixIcon: const Icon(Icons.search_rounded), suffixIcon: _query.isEmpty ? null : IconButton(onPressed: () { setState(() => _query = ''); }, icon: const Icon(Icons.close_rounded)))),
          const SizedBox(height: 14),
          SizedBox(height: 38, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: categories.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (_, index) { final item = categories[index]; return ChoiceChip(label: Text(item), selected: _category == item, onSelected: (_) => setState(() => _category = item)); })),
          if (_category == 'الكل' && _query.isEmpty) ...[
            const SizedBox(height: 20),
            const Text('مقترحة لك', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            SizedBox(height: 154, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: featured.length, separatorBuilder: (_, __) => const SizedBox(width: 10), itemBuilder: (_, index) => _FeaturedGameCard(game: featured[index], onTap: () => _open(featured[index])))),
            const SizedBox(height: 22),
          ],
          Row(children: [const Text('كل الألعاب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const Spacer(), Text('${_games.length} لعبة', style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700))]),
          const SizedBox(height: 10),
          if (_games.isEmpty) const Padding(padding: EdgeInsets.all(36), child: Center(child: Text('لا توجد ألعاب مطابقة للبحث.'))),
          ..._games.map((game) => Padding(padding: const EdgeInsets.only(bottom: 9), child: _GameListTile(game: game, onTap: () => _open(game)))),
        ],
      ),
    );
  }

  void _showInfo(BuildContext context) => showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (_) => const Padding(padding: EdgeInsets.fromLTRB(22, 8, 22, 28), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('ألعاب MemoChat', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), SizedBox(height: 10), Text('كل لعبة تعمل بجولة فعلية مع وقت ونقاط ومستوى ونتيجة شخصية. يتم حفظ أفضل نتيجة محلياً، ومزامنتها مع حسابك عند توفر الاتصال.', style: TextStyle(height: 1.5))]));
}

class _FeaturedGameCard extends StatelessWidget { const _FeaturedGameCard({required this.game, required this.onTap}); final GameDefinition game; final VoidCallback onTap; @override Widget build(BuildContext context) => SizedBox(width: 250, child: Card(clipBehavior: Clip.antiAlias, child: InkWell(onTap: onTap, child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [game.color, Color.lerp(game.color, Colors.black, .28)!], begin: Alignment.topRight, end: Alignment.bottomLeft)), padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(game.icon, color: Colors.white, size: 30), const Spacer(), Text(game.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(game.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11)), const SizedBox(height: 8), const Row(children: [Icon(Icons.play_arrow_rounded, color: Colors.white, size: 17), SizedBox(width: 4), Text('ابدأ الآن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))])])))); }
class _GameListTile extends StatelessWidget { const _GameListTile({required this.game, required this.onTap}); final GameDefinition game; final VoidCallback onTap; @override Widget build(BuildContext context) => Card(child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: game.color.withOpacity(.12), borderRadius: BorderRadius.circular(15)), child: Icon(game.icon, color: game.color, size: 25)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(game.title, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(game.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12))])), Icon(Icons.play_circle_outline_rounded, color: game.color)])))); }
