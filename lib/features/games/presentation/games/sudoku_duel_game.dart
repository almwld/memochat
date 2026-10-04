import 'package:flutter/material.dart';

class SudokuDuelGame extends StatefulWidget {
  const SudokuDuelGame({super.key});
  @override State<SudokuDuelGame> createState() => _SudokuDuelGameState();
}

class _SudokuDuelGameState extends State<SudokuDuelGame> {
  final solution = <int>[5,3,4,6,7,8,9,1,2,6,7,2,1,9,5,3,4,8,1,9,8,3,4,2,5,6,7,8,5,9,7,6,1,4,2,3];
  final puzzle = <int>[5,3,0,6,0,8,9,0,2,0,7,2,1,0,5,0,4,8,1,0,8,0,4,0,5,6,0,8,5,0,7,6,0,4,0,3];
  static const givens = <int>{0,1,3,5,6,8,10,11,12,14,15,16,18,20,23,24,25,27,28,30,31,33,35};
  int selected = -1, mistakes = 0, filled = 0;

  void place(int value) {
    if (selected < 0 || givens.contains(selected)) return;
    if (value == solution[selected]) {
      setState(() { puzzle[selected] = value; filled++; selected = -1; });
    } else {
      setState(() => mistakes++);
    }
  }

  void reset() => setState(() {
    for (int i = 0; i < puzzle.length; i++) {
      if (!givens.contains(i)) puzzle[i] = 0;
    }
    selected = -1; mistakes = 0; filled = 0;
  });

  @override Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final complete = puzzle.every((v) => v != 0);
    return Scaffold(
      appBar: AppBar(title: const Text('Sudoku Duel'), centerTitle: true,
        actions: [IconButton(onPressed: reset, icon: const Icon(Icons.refresh_rounded))]),
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('التقدم ${filled}/13', style: const TextStyle(fontWeight: FontWeight.w900)),
            Text('أخطاء $mistakes', style: TextStyle(color: mistakes > 2 ? cs.error : cs.onSurfaceVariant, fontWeight: FontWeight.w800)),
          ],
        )),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: AspectRatio(aspectRatio: 1,
          child: Container(decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outlineVariant, width: 2)),
            child: GridView.builder(physics: const NeverScrollableScrollPhysics(), itemCount: 36,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6),
              itemBuilder: (_, i) {
                final active = selected == i;
                return GestureDetector(onTap: () => setState(() => selected = i),
                  child: Container(margin: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(color: active ? cs.primaryContainer : cs.surface,
                      border: Border.all(color: cs.outlineVariant)),
                    child: Center(child: Text(puzzle[i] == 0 ? '' : '${puzzle[i]}',
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900,
                        color: givens.contains(i) ? cs.onSurface : cs.primary)))));
              },
            ),
          ))),
        const SizedBox(height: 18),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
          children: List.generate(9, (i) => SizedBox(width: 54, height: 46,
            child: FilledButton.tonal(onPressed: () => place(i + 1), child: Text('${i + 1}'))))),
        const SizedBox(height: 16),
        if (complete) Text('اكتملت اللوحة — نتيجة ممتازة', style: TextStyle(color: cs.primary, fontSize: 19, fontWeight: FontWeight.w900)),
      ])),
    );
  }
}