import 'package:flutter/material.dart';

class MazeRunnerGame extends StatefulWidget {
  const MazeRunnerGame({super.key});
  @override
  State<MazeRunnerGame> createState() => _MazeRunnerGameState();
}

class _MazeRunnerGameState extends State<MazeRunnerGame> {
  static const size = 5;
  static const List<List<int>> _stages = [
    [0, 1, 2, 3, 8, 13, 18, 19, 24],
    [0, 5, 10, 11, 12, 17, 22, 23, 24],
    [0, 1, 6, 11, 16, 17, 18, 23, 24],
    [0, 5, 6, 7, 12, 17, 18, 19, 24],
    [0, 1, 2, 7, 12, 13, 14, 19, 24],
  ];

  final path = <int>{};
  int player = 0, moves = 0, stage = 1;
  bool won = false;

  @override
  void initState() {
    super.initState();
    path.addAll(_stages.first);
  }

  void move(int delta) {
    if (won) return;
    final next = player + delta;
    if (next < 0 || next >= size * size) return;
    final sameRow = delta.abs() != 1 || player ~/ size == next ~/ size;
    if (!sameRow || !path.contains(next)) return;
    setState(() {
      player = next;
      moves++;
      won = player == size * size - 1;
    });
  }

  void _nextStage() {
    setState(() {
      stage = stage == _stages.length ? 1 : stage + 1;
      path
        ..clear()
        ..addAll(_stages[stage - 1]);
      player = 0;
      moves = 0;
      won = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('متاهة المسار'), centerTitle: true),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'المرحلة $stage من ${_stages.length}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Text('الحركات: $moves',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              child: Text(
                won
                    ? 'أحسنت! وصلت إلى العلم. اضغط «المرحلة التالية».'
                    : 'ابدأ من اللاعب 🟢 واتبع الخانات المضيئة حتى العلم 🏁.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.swipe_rounded, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تنبيه: استخدم أزرار الأسهم للتحرك. لوحة المتاهة ثابتة ولا تحتاج إلى تمرير أو سحب.',
                      style: TextStyle(fontSize: 12, height: 1.25),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(14),
                    itemCount: size * size,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: size,
                    ),
                    itemBuilder: (_, i) {
                      final active = path.contains(i);
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: i == player
                              ? cs.primary
                              : i == size * size - 1
                                  ? cs.tertiaryContainer
                                  : active
                                      ? cs.surfaceContainerHighest
                                      : cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Center(
                          child: Icon(
                            i == player
                                ? Icons.person_pin_circle_rounded
                                : i == size * size - 1
                                    ? Icons.flag_rounded
                                    : active
                                        ? Icons.circle
                                        : Icons.block,
                            size: i == player ? 30 : 18,
                            color: i == player ? cs.onPrimary : cs.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            if (won)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FilledButton.icon(
                  onPressed: _nextStage,
                  icon: const Icon(Icons.flag_rounded),
                  label: Text(stage == _stages.length ? 'إعادة من المرحلة الأولى' : 'المرحلة التالية'),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                children: [
                  IconButton.filled(
                    onPressed: () => move(-size),
                    tooltip: 'تحرك للأعلى',
                    icon: const Icon(Icons.keyboard_arrow_up_rounded),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filled(
                        onPressed: () => move(-1),
                        tooltip: 'تحرك لليسار',
                        icon: const Icon(Icons.keyboard_arrow_left_rounded),
                      ),
                      const SizedBox(width: 18),
                      IconButton.filled(
                        onPressed: () => move(1),
                        tooltip: 'تحرك لليمين',
                        icon: const Icon(Icons.keyboard_arrow_right_rounded),
                      ),
                    ],
                  ),
                  IconButton.filled(
                    onPressed: () => move(size),
                    tooltip: 'تحرك للأسفل',
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
