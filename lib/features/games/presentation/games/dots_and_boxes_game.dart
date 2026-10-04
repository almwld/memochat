import 'package:flutter/material.dart';

class DotsAndBoxesGame extends StatefulWidget {
  const DotsAndBoxesGame({super.key});
  @override State<DotsAndBoxesGame> createState() => _DotsAndBoxesGameState();
}

class _DotsAndBoxesGameState extends State<DotsAndBoxesGame> {
  static const n = 4;
  final h = <String>{}, v = <String>{}, boxes = <String>{};
  int score = 0;

  bool _boxComplete(int r, int c) =>
      h.contains('$r-$c') && h.contains('${r + 1}-$c') &&
      v.contains('$r-$c') && v.contains('$r-${c + 1}');

  void _edge(String key, bool horizontal, int r, int c) {
    final set = horizontal ? h : v;
    if (set.contains(key)) return;
    set.add(key);
    int gained = 0;
    for (int br = 0; br < n - 1; br++) {
      for (int bc = 0; bc < n - 1; bc++) {
        final id = '$br-$bc';
        if (!boxes.contains(id) && _boxComplete(br, bc)) { boxes.add(id); gained++; }
      }
    }
    setState(() => score += gained);
  }

  @override Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Dots & Boxes'), centerTitle: true),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('النقاط $score', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            Text('${boxes.length}/${(n - 1) * (n - 1)} مربعات', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
          ],
        )),
        Expanded(child: Center(child: AspectRatio(aspectRatio: 1, child: GridView.builder(
          padding: const EdgeInsets.all(22), itemCount: n * n,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: n),
          itemBuilder: (_, i) {
            final r = i ~/ n, c = i % n;
            return Stack(children: [
              Align(alignment: Alignment.topLeft, child: Container(width: 10, height: 10,
                decoration: BoxDecoration(color: cs.onSurface, shape: BoxShape.circle))),
              if (c < n - 1) Positioned(left: 8, right: 0, top: 2, height: 8,
                child: GestureDetector(onTap: () => _edge('$r-$c', true, r, c),
                  child: AnimatedContainer(duration: const Duration(milliseconds: 160),
                    decoration: BoxDecoration(color: h.contains('$r-$c') ? cs.primary : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8))))),
              if (r < n - 1) Positioned(top: 8, bottom: 0, left: 2, width: 8,
                child: GestureDetector(onTap: () => _edge('$r-$c', false, r, c),
                  child: AnimatedContainer(duration: const Duration(milliseconds: 160),
                    decoration: BoxDecoration(color: v.contains('$r-$c') ? cs.primary : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8))))),
              if (r < n - 1 && c < n - 1 && boxes.contains('$r-$c'))
                Align(alignment: Alignment.center, child: Icon(Icons.check_rounded, color: cs.primary, size: 28)),
            ]);
          },
        )))),
        if (boxes.length == (n - 1) * (n - 1))
          Padding(padding: const EdgeInsets.only(bottom: 24), child: Text('انتهت الجولة — أحسنت!', style: TextStyle(color: cs.primary, fontSize: 20, fontWeight: FontWeight.w900))),
      ]),
    );
  }
}