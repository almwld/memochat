import 'package:flutter/material.dart';

class DotsAndBoxesGame extends StatefulWidget {
  const DotsAndBoxesGame({super.key});

  @override
  State<DotsAndBoxesGame> createState() => _DotsAndBoxesGameState();
}

class _DotsAndBoxesGameState extends State<DotsAndBoxesGame> {
  static const int _gridSize = 4;
  final Set<String> _horizontalEdges = <String>{};
  final Set<String> _verticalEdges = <String>{};
  final Set<String> _completedBoxes = <String>{};
  int _score = 0;

  bool _isBoxComplete(int row, int column) =>
      _horizontalEdges.contains('$row-$column') &&
      _horizontalEdges.contains('${row + 1}-$column') &&
      _verticalEdges.contains('$row-$column') &&
      _verticalEdges.contains('$row-${column + 1}');

  void _selectEdge(String key, {required bool horizontal}) {
    final edges = horizontal ? _horizontalEdges : _verticalEdges;
    if (edges.contains(key) || _completedBoxes.length == 9) return;

    var gained = 0;
    setState(() {
      edges.add(key);
      for (var row = 0; row < _gridSize - 1; row++) {
        for (var column = 0; column < _gridSize - 1; column++) {
          final boxId = '$row-$column';
          if (!_completedBoxes.contains(boxId) &&
              _isBoxComplete(row, column)) {
            _completedBoxes.add(boxId);
            gained++;
          }
        }
      }
      _score += gained;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const totalBoxes = (_gridSize - 1) * (_gridSize - 1);
    final isComplete = _completedBoxes.length == totalBoxes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dots & Boxes'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'إعادة اللعب',
            onPressed: _reset,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'النقاط: $_score',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${_completedBoxes.length}/$totalBoxes مربعات',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
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
                  padding: const EdgeInsets.all(22),
                  itemCount: _gridSize * _gridSize,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _gridSize,
                  ),
                  itemBuilder: (context, index) {
                    final row = index ~/ _gridSize;
                    final column = index % _gridSize;
                    final horizontalKey = '$row-$column';
                    final verticalKey = '$row-$column';
                    final boxId = '$row-$column';

                    return Stack(
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: colors.onSurface,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        if (column < _gridSize - 1)
                          Positioned(
                            left: 8,
                            right: 0,
                            top: 2,
                            height: 8,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _selectEdge(
                                horizontalKey,
                                horizontal: true,
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                decoration: BoxDecoration(
                                  color: _horizontalEdges.contains(horizontalKey)
                                      ? colors.primary
                                      : colors.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        if (row < _gridSize - 1)
                          Positioned(
                            top: 8,
                            bottom: 0,
                            left: 2,
                            width: 8,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _selectEdge(
                                verticalKey,
                                horizontal: false,
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                decoration: BoxDecoration(
                                  color: _verticalEdges.contains(verticalKey)
                                      ? colors.primary
                                      : colors.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        if (row < _gridSize - 1 &&
                            column < _gridSize - 1 &&
                            _completedBoxes.contains(boxId))
                          Align(
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.check_rounded,
                              color: colors.primary,
                              size: 28,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          if (isComplete)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Text(
                'انتهت الجولة — أحسنت!',
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _reset() {
    setState(() {
      _horizontalEdges.clear();
      _verticalEdges.clear();
      _completedBoxes.clear();
      _score = 0;
    });
  }
}
