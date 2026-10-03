import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/game.dart';

class GamePlayScreen extends StatefulWidget {
  final GameType type;
  final String title;
  const GamePlayScreen({super.key, required this.type, required this.title});

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen> {
  int score = 0;
  int _step = 0;
  bool _done = false;
  final _random = Random();
  final List<String> _xo = List.filled(9, '');
  String _word = 'كتاب';
  String _truthOrDare = '';
  int _quickTaps = 0;
  int _reactionTarget = 0;
  Timer? _timer;
  int _seconds = 30;
  int _mathA = 7, _mathB = 5;
  String _mathOp = '+';
  int _mathAnswer = 12;
  final List<int> _memory = [];
  final Set<int> _memoryOpen = {};
  final Set<int> _memoryMatched = {};
  final List<String> _sudoku = [
    '1','2','3','4',
    '3','4','1','2',
    '2','1','4','3',
    '4','3','2','1',
  ];
  final List<String> _sudokuUser = List.filled(16, '');

  @override
  void initState() {
    super.initState();
    _newRound();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _newRound() {
    _step++;
    _done = false;
    _reactionTarget = _random.nextInt(4);
    _mathA = 2 + _random.nextInt(18);
    _mathB = 2 + _random.nextInt(12);
    final ops = ['+', '-', '×'];
    _mathOp = ops[_random.nextInt(ops.length)];
    _mathAnswer = _mathOp == '+'
        ? _mathA + _mathB
        : _mathOp == '-'
            ? _mathA - _mathB
            : _mathA * _mathB;
    if (widget.type == GameType.memoryMatch) {
      _memory
        ..clear()
        ..addAll([0, 1, 2, 3, 0, 1, 2, 3]..shuffle(_random));
      _memoryOpen.clear();
      _memoryMatched.clear();
    }
  }

  void _point({int value = 1}) {
    if (!mounted) return;
    setState(() => score += value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _gameBody(),
        ),
      ),
    );
  }

  Widget _gameBody() {
    switch (widget.type) {
      case GameType.xo: return _xoGame();
      case GameType.quizBattle: return _quizGame();
      case GameType.emojiReaction: return _reactionGame();
      case GameType.diceRoll: return _diceGame();
      case GameType.drawGuess: return _drawGame();
      case GameType.wordChain: return _wordGame();
      case GameType.truthDare: return _truthDareGame();
      case GameType.guessSong: return _choiceGame('خمن الأغنية', ['🎵 أغنية عربية','🎸 أغنية روك','🎹 أغنية كلاسيكية','🥁 أغنية شعبية']);
      case GameType.memoryMatch: return _memoryGame();
      case GameType.triviaChallenge: return _choiceGame('Trivia Challenge', ['المحيط الهادئ','المريخ','الأمازون','جبال الألب']);
      case GameType.quickTap: return _quickTapGame();
      case GameType.wouldYouRather: return _choiceGame('ماذا تفضل؟', ['السفر عبر الزمن','قراءة الأفكار','الطيران','التنفس تحت الماء']);
      case GameType.speedMath: return _speedMathGame();
      case GameType.movieQuiz: return _choiceGame('Movie Quiz', ['Inception','Interstellar','Avatar','The Matrix']);
      case GameType.sudokuDuel: return _sudokuGame();
    }
  }

  Widget _header(String subtitle) => Column(
        children: [
          Text(subtitle, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('النقاط: $score', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 18),
        ],
      );

  Widget _action(String text, VoidCallback onTap) => SizedBox(
        width: double.infinity,
        child: FilledButton(onPressed: onTap, child: Text(text)),
      );

  Widget _xoGame() {
    String winner = '';
    for (final line in const [[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]]) {
      if (_xo[line[0]].isNotEmpty && _xo[line[0]] == _xo[line[1]] && _xo[line[1]] == _xo[line[2]]) winner = _xo[line[0]];
    }
    final full = _xo.every((e) => e.isNotEmpty);
    return Column(children: [
      _header('إكس أو'),
      if (winner.isNotEmpty || full) Text(winner.isEmpty ? 'تعادل' : 'الفائز: $winner',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        itemCount: 9, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
        itemBuilder: (_, i) => InkWell(
          onTap: _xo[i].isNotEmpty || winner.isNotEmpty ? null : () {
            setState(() => _xo[i] = i.isEven ? 'X' : 'O');
          },
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outline), borderRadius: BorderRadius.circular(14)),
            child: Center(child: Text(_xo[i], style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900))),
          ),
        ),
      ),
      const SizedBox(height: 14),
      _action('إعادة اللعب', () => setState(() { _xo.fillRange(0, 9, ''); score = 0; })),
    ]);
  }

  Widget _quizGame() => _quizLike(
    'Quiz Battle',
    'ما هو الكوكب المعروف بالكوكب الأحمر؟',
    ['الأرض','المريخ','الزهرة','المشتري'],
    1,
  );

  Widget _quizLike(String title, String question, List<String> answers, int correct) => Column(children: [
    _header(title),
    Text(question, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
    const SizedBox(height: 18),
    ...List.generate(answers.length, (i) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _action(answers[i], () {
        _point(value: i == correct ? 2 : 0);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(i == correct ? 'إجابة صحيحة ✓' : 'حاول مرة أخرى')));
      }),
    )),
  ]);

  Widget _reactionGame() {
    final labels = ['❤️','😂','🔥','👏'];
    return Column(children: [
      _header('Emoji Reaction'),
      const Text('اضغط على الإيموجي المطلوب بأسرع ما يمكن'),
      const SizedBox(height: 18),
      Text(labels[_reactionTarget], style: const TextStyle(fontSize: 48)),
      const SizedBox(height: 18),
      Wrap(spacing: 12, runSpacing: 12, children: List.generate(labels.length, (i) =>
        OutlinedButton(onPressed: () {
          if (i == _reactionTarget) {
            _point(value: 2);
            setState(_newRound);
          }
        }, child: Text(labels[i], style: const TextStyle(fontSize: 28))))),
    ]);
  }

  Widget _diceGame() {
    final value = _step % 6 + 1;
    return Column(children: [
      _header('Dice Roll'),
      Text('🎲 $value', style: const TextStyle(fontSize: 64)),
      _action('ارمِ النرد', () => setState(() {
        _step = _random.nextInt(6);
        score += _step + 1;
      })),
    ]);
  }

  Widget _drawGame() => Column(children: [
    _header('Draw & Guess'),
    const Text('ارسم كلمة بسيطة في المساحة، ثم شارك الشاشة مع الطرف الآخر.'),
    const SizedBox(height: 12),
    Container(
      height: 280,
      decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outline), borderRadius: BorderRadius.circular(18)),
      child: CustomPaint(painter: _GridPainter()),
    ),
    const SizedBox(height: 12),
    _action('خمنت الكلمة ✓', () => _point(value: 2)),
  ]);

  Widget _wordGame() => Column(children: [
    _header('Word Chain'),
    Text('ابدأ بكلمة تنتهي بحرف بداية الكلمة السابقة.'),
    const SizedBox(height: 12),
    Text('الكلمة الحالية: $_word', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    const SizedBox(height: 12),
    TextField(
      textDirection: TextDirection.rtl,
      decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'اكتب كلمتك'),
      onSubmitted: (v) {
        if (v.trim().isEmpty) return;
        final last = _word.characters.last;
        if (v.trim().startsWith(last)) {
          _point(value: 2);
          setState(() => _word = v.trim());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب أن تبدأ الكلمة بالحرف الأخير.')));
        }
      },
    ),
  ]);

  Widget _truthDareGame() => Column(children: [
    _header('Truth or Dare'),
    if (_truthOrDare.isNotEmpty) Padding(
      padding: const EdgeInsets.all(18),
      child: Text(_truthOrDare, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
    ),
    Row(children: [
      Expanded(child: _action('صراحة', () => setState(() => _truthOrDare = 'ما أكثر شيء تتمنى تعلمه هذا العام؟'))),
      const SizedBox(width: 10),
      Expanded(child: _action('تحدي', () => setState(() => _truthOrDare = 'قل جملة مضحكة بصوت جاد.'))),
    ]),
  ]);

  Widget _choiceGame(String title, List<String> options) => Column(children: [
    _header(title),
    const Text('اختر إجابة لتسجيل نقطة.'),
    const SizedBox(height: 16),
    ...options.map((e) => Padding(padding: const EdgeInsets.only(bottom: 10),
      child: _action(e, () => _point(value: 1)))),
  ]);

  Widget _memoryGame() {
    final icons = ['🍎','🚀','⚽','🎵'];
    return Column(children: [
      _header('Memory Match'),
      GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: 8,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4),
        itemBuilder: (_, i) {
          final visible = _memoryOpen.contains(i) || _memoryMatched.contains(i);
          return InkWell(
            onTap: visible ? null : () {
              setState(() => _memoryOpen.add(i));
              if (_memoryOpen.length == 2) {
                final a = _memoryOpen.elementAt(0), b = _memoryOpen.elementAt(1);
                if (_memory[a] == _memory[b]) {
                  setState(() { _memoryMatched.addAll([a,b]); _memoryOpen.clear(); score += 2; });
                } else {
                  Future.delayed(const Duration(milliseconds: 550), () {
                    if (mounted) setState(_memoryOpen.clear);
                  });
                }
              }
            },
            child: Card(child: Center(child: Text(visible ? icons[_memory[i]] : '?', style: const TextStyle(fontSize: 28)))),
          );
        },
      ),
    ]);
  }

  Widget _quickTapGame() => Column(children: [
    _header('Quick Tap'),
    const Text('اضغط الزر أكبر عدد ممكن خلال 10 ثوانٍ.'),
    const SizedBox(height: 20),
    Text('$_quickTaps', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900)),
    _action('اضغط!', () => _point(value: 1)),
  ]);

  Widget _speedMathGame() {
    final choices = <int>{_mathAnswer};
    while (choices.length < 4) choices.add(_mathAnswer + _random.nextInt(11) - 5);
    final list = choices.toList()..shuffle(_random);
    return Column(children: [
      _header('Speed Math'),
      Text('$_mathA $_mathOp $_mathB = ؟', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
      const SizedBox(height: 18),
      ...list.map((n) => Padding(padding: const EdgeInsets.only(bottom: 10),
        child: _action('$n', () {
          if (n == _mathAnswer) {
            _point(value: 2);
            setState(_newRound);
          }
        }))),
    ]);
  }

  Widget _sudokuGame() => Column(children: [
    _header('Sudoku Duel'),
    const Text('أكمل الخانات الفارغة في شبكة 4×4.'),
    const SizedBox(height: 12),
    GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: 16,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4),
      itemBuilder: (_, i) {
        final given = i % 3 == 0 || i == 5 || i == 10 || i == 15;
        return Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outline)),
          child: given ? Center(child: Text(_sudoku[i], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)))
            : TextField(
              textAlign: TextAlign.center, keyboardType: TextInputType.number, maxLength: 1,
              decoration: const InputDecoration(counterText: '', border: InputBorder.none),
              onChanged: (v) { if (v == _sudoku[i]) _point(); },
            ),
        );
      },
    ),
  ]);
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.stroke..strokeWidth = 3;
    final path = Path()..moveTo(30, size.height * .6)..quadraticBezierTo(size.width * .3, size.height * .1, size.width * .5, size.height * .55)..quadraticBezierTo(size.width * .75, size.height * .9, size.width - 30, size.height * .25);
    canvas.drawPath(path, p);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
