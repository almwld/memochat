import 'package:flutter/material.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/premium_ui.dart';
import '../data/games_catalog.dart';
import '../models/game.dart';
import 'game_play_screen.dart';
import 'widgets/game_art.dart';

class GamesHubScreen extends StatefulWidget {
  const GamesHubScreen({super.key});
  @override State<GamesHubScreen> createState() => _GamesHubScreenState();
}

class _GamesHubScreenState extends State<GamesHubScreen> {
  String _category = 'الكل';
  String _query = '';

  String _categoryOf(GameType type) {
    final value = type.name.toLowerCase();
    if (value.contains('quiz') || value.contains('trivia') || value == 'truefalse') return 'معرفة';
    if (value.contains('word') || value.contains('anagram') || value == 'languagequiz') return 'كلمات';
    if (value.contains('math') || value == 'numberguess' || value == 'codebreaker') return 'منطق';
    if (value.contains('memory') || value.contains('sequence') || value == 'patterntap') return 'ذاكرة';
    if (value.contains('color') || value.contains('reaction') || value == 'quicktap') return 'سرعة';
    if (value.contains('maze') || value.contains('rocket') || value.contains('galaxy') || value == 'treasurehunt') return 'مغامرة';
    return 'تحديات';
  }

  List<GameDefinition> get _games {
    final q = _query.trim().toLowerCase();
    return GamesCatalog.all.where((game) =>
      (_category == 'الكل' || _categoryOf(game.type) == _category) &&
      (q.isEmpty || game.title.toLowerCase().contains(q) || game.subtitle.toLowerCase().contains(q))
    ).toList();
  }

  void _open(GameDefinition game) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GamePlayScreen(type: game.type, title: game.title, chatId: ''),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const categories = ['الكل','سرعة','ذاكرة','منطق','كلمات','معرفة','مغامرة','تحديات'];
    final featured = GamesCatalog.all.take(6).toList();

    return ScrollAwareScaffold(
      appBar: AppBar(
        title: const Text('ألعاب MemoChat', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            onPressed: () => _showInfo(context),
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'عن الألعاب',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16,8,16,110),
        children: [
          const PremiumHero(
            icon: AppIcons.chat,
            title: 'وقت اللعب',
            subtitle: '55 تحدياً فعلياً بنقاط ومستويات ونتائج شخصية، ضمن نفس هوية MemoChat.',
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'ابحث في الألعاب...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty ? null : IconButton(
                onPressed: () => setState(() => _query = ''),
                icon: const Icon(Icons.close_rounded),
                tooltip: 'مسح البحث',
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final item = categories[index];
                return ChoiceChip(
                  label: Text(item),
                  selected: _category == item,
                  onSelected: (_) => setState(() => _category = item),
                );
              },
            ),
          ),
          if (_category == 'الكل' && _query.isEmpty) ...[
            const SizedBox(height: 20),
            const Text('ابدأ بتحدٍّ مقترح', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            SizedBox(
              height: 166,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: featured.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, index) => _FeaturedGameCard(
                  game: featured[index],
                  onTap: () => _open(featured[index]),
                ),
              ),
            ),
            const SizedBox(height: 22),
          ],
          Row(
            children: [
              const Text('كل الألعاب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const Spacer(),
              Text('${_games.length} لعبة', style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          if (_games.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded, size: 38, color: scheme.onSurfaceVariant),
                    const SizedBox(height: 8),
                    const Text('لا توجد ألعاب مطابقة', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('جرّب كلمة بحث أخرى أو اختر تصنيفاً مختلفاً.', textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            )
          else
            ..._games.map((game) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _GameListTile(game: game, category: _categoryOf(game.type), onTap: () => _open(game)),
            )),
        ],
      ),
    );
  }

  void _showInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const Padding(
        padding: EdgeInsets.fromLTRB(22,8,22,28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ألعاب MemoChat', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            SizedBox(height: 10),
            Text('ألعاب فردية وتحديات جماعية داخل التطبيق، مع حفظ النتائج محلياً ومزامنة جلسات التحدي عبر خدمة الألعاب.', style: TextStyle(height: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _FeaturedGameCard extends StatelessWidget {
  const _FeaturedGameCard({required this.game, required this.onTap});
  final GameDefinition game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 250,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GameArt(type: game.type, size: 42, compact: true),
                const Spacer(),
                Text(game.title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(game.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Icon(Icons.play_arrow_rounded, color: Colors.white, size: 17),
                    SizedBox(width: 4),
                    Text('ابدأ الآن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GameListTile extends StatelessWidget {
  const _GameListTile({required this.game, required this.category, required this.onTap});
  final GameDefinition game;
  final String category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 10, 10),
          child: Row(
            children: [
              GameArt(type: game.type, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(game.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(game.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('$category • ${game.playersLabel}', style: TextStyle(color: scheme.primary, fontSize: 10, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Icon(Icons.play_circle_outline_rounded, color: scheme.primary),
            ],
          ),
        ),
      ),
    );  }
}
