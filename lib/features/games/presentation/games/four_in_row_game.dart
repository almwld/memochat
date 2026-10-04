import 'dart:math';
import 'package:flutter/material.dart';

class FourInRowGame extends StatefulWidget {
  const FourInRowGame({super.key});
  @override State<FourInRowGame> createState() => _FourInRowGameState();
}

class _FourInRowGameState extends State<FourInRowGame> {
  final board = List<int>.filled(42, 0);
  bool done = false;
  int turn = 1;

  void play(int col) {
    if (done) return;
    for (int row = 5; row >= 0; row--) {
      final i = row * 7 + col;
      if (board[i] == 0) {
        setState(() => board[i] = 1);
        if (_win(1) || board.every((x) => x != 0)) {
          setState(() => done = true);
          return;
        }
        setState(() => turn = 2);
        Future.delayed(const Duration(milliseconds: 260), _ai);
        return;
      }
    }
  }

  void _ai() {
    if (!mounted || done) return;
    final choices = List<int>.generate(7, (i) => i)..shuffle(Random());
    for (final col in choices) {
      for (int row = 5; row >= 0; row--) {
        final i = row * 7 + col;
        if (board[i] == 0) {
          setState(() {
            board[i] = 2;
            turn = 1;
          });
          if (_win(2) || board.every((x) => x != 0)) setState(() => done = true);
          return;
        }
      }
    }
  }

  bool _win(int p) {
    for (int r = 0; r < 6; r++) {
      for (int c = 0; c < 7; c++) {
        final i = r * 7 + c;
        if (c < 4 && [0,1,2,3].every((d) => board[i + d] == p)) return true;
        if (r < 3 && [0,7,14,21].every((d) => board[i + d] == p)) return true;
        if (r < 3 && c < 4 && [0,8,16,24].every((d) => board[i + d] == p)) return true;
        if (r < 3 && c > 2 && [0,6,12,18].every((d) => board[i + d] == p)) return true;
      }
    }
    return false;
  }

  void reset() => setState(() {
    board.fillRange(0, board.length, 0);
    done = false;
    turn = 1;
  });

  @override Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final winner = _win(1) ? 'أنت الفائز' : _win(2) ? 'الخصم فاز' : 'تعادل';
    return Scaffold(
      appBar: AppBar(title: const Text('Four in a Row'), centerTitle: true,
        actions: [IconButton(onPressed: reset, icon: const Icon(Icons.refresh_rounded))]),
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(done ? winner : turn == 1 ? 'دورك' : 'الخصم يفكر…',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const Icon(Icons.grid_3x3_rounded),
          ],
        )),
        Expanded(child: Center(child: AspectRatio(aspectRatio: 7 / 6, child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cs.primary.withOpacity(.35), width: 2)),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(), itemCount: 42,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => play(i % 7),
              child: Padding(padding: const EdgeInsets.all(3), child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: board[i] == 0 ? cs.surface : board[i] == 1 ? cs.primary : cs.tertiary,
                  boxShadow: board[i] == 0 ? null : [BoxShadow(color: cs.shadow.withOpacity(.16), blurRadius: 6, offset: const Offset(0, 2))]),
                child: board[i] == 0 ? null : Icon(board[i] == 1 ? Icons.circle : Icons.close_rounded,
                  color: board[i] == 1 ? cs.onPrimary : cs.onTertiary, size: 22),
              )),
            ),
          ),
        )))),
        Padding(padding: const EdgeInsets.all(18), child: Text(
          done ? 'اضغط إعادة لبدء جولة جديدة' : 'اختر العمود لإسقاط القطعة',
          style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700))),
      ])),
    );
  }
}