import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class DiceRollGame extends StatefulWidget {
  const DiceRollGame({super.key});
  @override State<DiceRollGame> createState() => _DiceRollGameState();
}

class _DiceRollGameState extends State<DiceRollGame> {
  final random = Random();
  int value = 1, best = 0, rolls = 0;
  bool rolling = false;

  Future<void> roll() async {
    if (rolling) return;
    setState(() => rolling = true);
    for (int i = 0; i < 8; i++) {
      await Future.delayed(const Duration(milliseconds: 70));
      if (!mounted) return;
      setState(() => value = random.nextInt(6) + 1);
    }
    setState(() {
      rolling = false;
      rolls++;
      if (value > best) best = value;
    });
  }

  @override Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Dice Roll'), centerTitle: true),
      body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('ارمِ النرد وحاول تحطيم أفضل نتيجة',
            textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 17)),
          const SizedBox(height: 28),
          AnimatedScale(scale: rolling ? 1.08 : 1, duration: const Duration(milliseconds: 100),
            child: Container(width: 150, height: 150,
              decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(30),
                border: Border.all(color: cs.primary, width: 2)),
              child: Center(child: Text('$value',
                style: TextStyle(fontSize: 72, fontWeight: FontWeight.w900, color: cs.primary))))),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _stat('أفضل', '$best'),
            const SizedBox(width: 28),
            _stat('الرميات', '$rolls'),
          ]),
          const SizedBox(height: 28),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: rolling ? null : roll,
            icon: Icon(rolling ? Icons.hourglass_top_rounded : Icons.casino_rounded),
            label: Padding(padding: const EdgeInsets.symmetric(vertical: 13), child: Text(rolling ? 'جارٍ الرمي...' : 'ارمِ النرد')),
          )),
        ],
      ))),
    );
  }

  Widget _stat(String label, String value) => Column(children: [
    Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
  ]);
}