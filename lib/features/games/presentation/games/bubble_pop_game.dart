import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../runtime/arcade_game_runtime.dart';

/// Bubble Pop is a real-time arcade game, not a multiple-choice screen.
class BubblePopGame extends StatefulWidget {
  const BubblePopGame({super.key});

  @override
  State<BubblePopGame> createState() => _BubblePopGameState();
}

class _BubblePopGameState extends State<BubblePopGame> {
  late final BubblePopArcadeGame _game;
  int _score = 0;

  @override
  void initState() {
    super.initState();
    _game = BubblePopArcadeGame(onScore: (score) {
      if (mounted) setState(() => _score = score);
    });
  }

  @override
  void dispose() {
    _game.pauseEngine();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bubble Pop'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.bubble_chart_rounded),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'فقاعات متحركة',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '$_score نقطة',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          Expanded(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                final box = context.findRenderObject() as RenderBox;
                final point = box.globalToLocal(event.position);
                // The game occupies the lower portion of the screen.
                final headerHeight = 58.0;
                _game.tap(Vector2(point.dx, point.dy - headerHeight));
              },
              child: GameWidget(game: _game),
            ),
          ),
        ],
      ),
    );
  }
}
