import 'dart:async';
import 'package:flutter/material.dart';

class MemoryMatchGame extends StatefulWidget {
  const MemoryMatchGame({super.key});
  @override State<MemoryMatchGame> createState() => _MemoryMatchGameState();
}

class _MemoryMatchGameState extends State<MemoryMatchGame> {
  static const faces = <IconData>[
    Icons.star_rounded, Icons.bolt_rounded, Icons.favorite_rounded, Icons.lock_rounded,
  ];
  late List<int> cards;
  final open = <int>{};
  final matched = <int>{};
  int moves = 0;
  bool locked = false;

  @override void initState() { super.initState(); _reset(); }

  void _reset() {
    cards = [0,0,1,1,2,2,3,3]..shuffle();
    open.clear(); matched.clear(); moves = 0; locked = false;
    setState(() {});
  }

  Future<void> _tap(int i) async {
    if (locked || matched.contains(i) || open.contains(i)) return;
    setState(() => open.add(i));
    if (open.length < 2) return;
    final pair = open.toList();
    moves++;
    if (cards[pair[0]] == cards[pair[1]]) {
      setState(() { matched.addAll(pair); open.clear(); });
    } else {
      locked = true;
      await Future.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      setState(() { open.clear(); locked = false; });
    }
  }

  @override Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final done = matched.length == cards.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Memory Match'), centerTitle: true,
        actions: [IconButton(onPressed: _reset, icon: const Icon(Icons.refresh_rounded))]),
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.all(18), child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('المحاولات $moves', style: const TextStyle(fontWeight: FontWeight.w900)),
            Text('${matched.length / 2}/4 أزواج', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800)),
          ],
        )),
        Expanded(child: Center(child: Padding(padding: const EdgeInsets.all(22), child: GridView.builder(
          shrinkWrap: true, itemCount: cards.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 10, mainAxisSpacing: 10),
          itemBuilder: (_, i) {
            final visible = open.contains(i) || matched.contains(i);
            return GestureDetector(onTap: () => _tap(i),
              child: AnimatedContainer(duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: visible ? cs.primaryContainer : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: visible ? cs.primary : cs.outlineVariant, width: 2),
                ),
                child: Center(child: AnimatedSwitcher(duration: const Duration(milliseconds: 160),
                  child: visible
                    ? Icon(faces[cards[i]], key: ValueKey(cards[i]), size: 34, color: cs.primary)
                    : Icon(Icons.question_mark_rounded, key: const ValueKey('hidden'), color: cs.onSurfaceVariant, size: 28))),
              ),
            );
          },
        )))),
        if (done) Padding(padding: const EdgeInsets.only(bottom: 28),
          child: Text('اكتملت اللعبة — ممتاز!', style: TextStyle(color: cs.primary, fontSize: 20, fontWeight: FontWeight.w900))),
      ])),
    );
  }
}