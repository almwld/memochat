import 'package:flutter/material.dart';

class DotsAndBoxesGame extends StatefulWidget {
  const DotsAndBoxesGame({super.key});
  @override
  State<DotsAndBoxesGame> createState() => _DotsAndBoxesGameState();
}

class _DotsAndBoxesGameState extends State<DotsAndBoxesGame> {
  final Set<String> h = <String>{};
  final Set<String> v = <String>{};
  int score = 0;

  void edge(String key, bool horizontal) {
    final set = horizontal ? h : v;
    if (set.contains(key)) return;
    setState(() {
      set.add(key);
      if (horizontal) score++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dots & Boxes')),
      body: Column(
        children: [
          Text('النقاط: $score', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Expanded(
            child: GridView.builder(
              itemCount: 16,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4),
              itemBuilder: (_, index) {
                final row = index ~/ 4;
                final col = index % 4;
                final verticalKey = '$row-$col-v';
                final horizontalKey = '$row-$col-h';
                return Stack(
                  children: [
                    const Center(child: SizedBox(width: 8, height: 8, child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle)))),
                    if (col < 3)
                      Positioned(
                        right: 0, top: 0, bottom: 0, width: 12,
                        child: GestureDetector(
                          onTap: () => edge(verticalKey, false),
                          child: Container(color: v.contains(verticalKey) ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest),
                        ),
                      ),
                    if (row < 3)
                      Positioned(
                        left: 0, right: 0, bottom: 0, height: 12,
                        child: GestureDetector(
                          onTap: () => edge(horizontalKey, true),
                          child: Container(color: h.contains(horizontalKey) ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
