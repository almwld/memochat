import 'package:flutter/material.dart';

class MazeRunnerGame extends StatefulWidget {
  const MazeRunnerGame({super.key});
  @override State<MazeRunnerGame> createState() => _MazeRunnerGameState();
}

class _MazeRunnerGameState extends State<MazeRunnerGame> {
  static const size = 5;
  final path = <int>{0,1,2,3,8,13,18,19,24};
  int player = 0, moves = 0;
  bool won = false;

  void move(int delta) {
    if (won) return;
    final next = player + delta;
    if (next < 0 || next >= size * size) return;
    final sameRow = delta.abs() != 1 || player ~/ size == next ~/ size;
    if (!sameRow || !path.contains(next)) return;
    setState(() { player = next; moves++; won = player == 24; });
  }

  @override Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Maze Runner'), centerTitle: true),
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('الحركات $moves', style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(won ? 'اكتمل المسار' : 'الوصول إلى الهدف', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800)),
          ])),
        Expanded(child: Center(child: AspectRatio(aspectRatio: 1, child: GridView.builder(
          padding: const EdgeInsets.all(20), itemCount: size * size,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: size),
          itemBuilder: (_, i) {
            final active = path.contains(i);
            return AnimatedContainer(duration: const Duration(milliseconds: 180), margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: i == player ? cs.primary : i == 24 ? cs.tertiaryContainer : active ? cs.surfaceContainerHighest : cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Center(child: Icon(i == player ? Icons.person_pin_circle_rounded : i == 24 ? Icons.flag_rounded : active ? Icons.circle : Icons.block,
                size: i == player ? 30 : 18, color: i == player ? cs.onPrimary : cs.onSurfaceVariant)));
          },
        )))),
        Padding(padding: const EdgeInsets.only(bottom: 18), child: Column(children: [
          IconButton.filled(onPressed: () => move(-size), icon: const Icon(Icons.keyboard_arrow_up_rounded)),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton.filled(onPressed: () => move(-1), icon: const Icon(Icons.keyboard_arrow_left_rounded)),
            const SizedBox(width: 18),
            IconButton.filled(onPressed: () => move(1), icon: const Icon(Icons.keyboard_arrow_right_rounded)),
          ]),
          IconButton.filled(onPressed: () => move(size), icon: const Icon(Icons.keyboard_arrow_down_rounded)),
        ])),
      ])),
    );
  }
}