import 'dart:math';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/game.dart';
import '../models/game_session.dart';
import '../services/game_service.dart';
import 'widgets/game_art.dart';

class ExtendedGamesBody extends StatefulWidget {
  final GameType type;
  final String title;
  final String chatId;
  final String? gameId;
  const ExtendedGamesBody({super.key, required this.type, required this.title, required this.chatId, this.gameId});
  @override State<ExtendedGamesBody> createState() => _ExtendedGamesBodyState();
}

class _ExtendedGamesBodyState extends State<ExtendedGamesBody> with SingleTickerProviderStateMixin {
  final _r = Random();
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 240))..repeat(reverse: true);
  int score = 0, round = 1, target = 0;
  String feedback = 'ابدأ الجولة';
  String? gameId;
  List<int> pattern = [];
  final Set<int> open = {};
  List<String> cards = [];
  Timer? _roundTimer;
  StreamSubscription<GameSession?>? _gameSubscription;
  String? _remoteUid;
  int _remoteScore = 0;
  int _seconds = 12;
  int _tapCount = 0;

  static const colors = [Color(0xFF10B9A6), Color(0xFF4C7DFF), Color(0xFFFFB84D), Color(0xFFEF6B8A), Color(0xFF8B6CFF)];

  @override void initState() { super.initState(); _newRound(); _findGame(); }
  @override void dispose() { _roundTimer?.cancel(); _gameSubscription?.cancel(); _pulse.dispose(); super.dispose(); }

  Future<void> _findGame() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || widget.chatId.trim().isEmpty) return;
    try {
      String? resolved = widget.gameId?.trim().isNotEmpty == true ? widget.gameId!.trim() : null;
      if (resolved == null) {
        final s = await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('games')
          .where('type', isEqualTo: widget.type.name).orderBy('createdAt', descending: true).limit(1).get();
        if (s.docs.isNotEmpty) resolved = s.docs.first.id;
      }
      if (resolved == null || !mounted) return;
      setState(() => gameId = resolved);
      _gameSubscription = GameService.instance.watchGame(widget.chatId, resolved).listen((game) {
        if (!mounted || game == null) return;
        final other = game.players.firstWhere((id) => id != uid, orElse: () => '');
        final raw = other.isEmpty ? null : game.scores[other];
        final remoteScore = raw?.toInt() ?? 0;
        setState(() {
          _remoteUid = other.isEmpty ? null : other;
          _remoteScore = remoteScore;
        });
      });
    } catch (_) {}
  }

  void _newRound() {
    target = _r.nextInt(4);
    pattern = List.generate(5, (_) => _r.nextInt(4));
    cards = ['🍎','🚀','🌙','🎵','⚽','🍀','⭐','🐳']..shuffle(_r);
    open.clear();
    feedback = 'اختر الحركة الصحيحة';
    _tapCount = 0;
    _seconds = 12;
    _roundTimer?.cancel();
    _roundTimer = Timer.periodic(const Duration(seconds: 1), (_) { if (!mounted) return; if (_seconds <= 1) { _roundTimer?.cancel(); setState(() => feedback = 'انتهى الوقت'); } else setState(() => _seconds--); });
    round++;
  }

  Future<void> _sync({Map<String,dynamic> state = const {}}) async {
    final id = gameId, uid = FirebaseAuth.instance.currentUser?.uid;
    if (id == null || uid == null) return;
    try {
      await GameService.instance.updatePlayerState(chatId: widget.chatId, gameId: id, uid: uid,
        state: {'game': widget.type.name, 'round': round, ...state}, score: score);
    } catch (_) {}
  }

  void _win([int points = 2, String text = 'رائع!']) {
    _roundTimer?.cancel();
    setState(() { score += points; feedback = text; });
    _sync(state: {'action': 'score', 'value': points});
    Future.delayed(const Duration(milliseconds: 220), () { if (mounted) setState(_newRound); });
  }

  Widget _tile(Widget child, VoidCallback tap, int i) => AnimatedBuilder(
    animation: _pulse,
    builder: (_, c) => Transform.scale(scale: 1 + (_pulse.value * .012), child: c),
    child: Material(
      elevation: 6, color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      shadowColor: colors[i % colors.length].withOpacity(.25),
      child: InkWell(borderRadius: BorderRadius.circular(24), onTap: tap,
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors[i % colors.length].withOpacity(.2))),
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    ),
  );

  Widget _head() => Column(children: [
    GameArt(type: widget.type, size: 76),
    const SizedBox(height: 6),
    Text(widget.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
    Text('الجولة $round  •  النقاط $score  •  $_seconds ث', style: const TextStyle(fontWeight: FontWeight.w700)),
    if (_remoteUid != null) Text('نقاط اللاعب الآخر: $_remoteScore', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    const SizedBox(height: 6), Text(feedback, textAlign: TextAlign.center),
  ]);


  Widget _grid(List<String> labels) => GridView.builder(
    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: labels.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2,crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:1.5),
    itemBuilder: (_,i) => _tile(Center(child: Text(labels[i],textAlign:TextAlign.center,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w800))), () {
      final correct = i == target;
      if (correct) _win(); else setState(() => feedback = 'حاول مرة أخرى حاول');
    }, i),
  );

  Widget _memory() => GridView.builder(
    shrinkWrap:true, physics:const NeverScrollableScrollPhysics(), itemCount:8,
    gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:4,crossAxisSpacing:8,mainAxisSpacing:8),
    itemBuilder:(_,i)=>_tile(Center(child:Text(open.contains(i)?cards[i]:'?',style:const TextStyle(fontSize:27))),(){
      if(open.contains(i)) return;
      setState(()=>open.add(i));
      if(open.length==2){
        final a=open.elementAt(0),b=open.elementAt(1);
        if(cards[a]==cards[b]) _win(3,'زوج متطابق! ممتاز');
        Future.delayed(const Duration(milliseconds:600),(){if(mounted)setState(open.clear);});
      }
    },i),
  );

  Widget _arena({String mode='num'}) {
    final labels = mode=='color' ? ['أحمر','أخضر','أزرق','بنفسجي']
      : mode=='shape' ? ['مثلث','دائرة','مربع','معين'] : ['1','2','3','4'];
    final icons = mode=='shape'
      ? [Icons.change_history_rounded,Icons.circle_rounded,Icons.square_rounded,Icons.diamond_rounded]
      : [Icons.circle,Icons.circle,Icons.circle,Icons.circle];
    return Column(children:[
      _head(), const SizedBox(height:18),
      Text('الهدف: ${labels[target]}',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
      const SizedBox(height:14),
      GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:4,
        gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,crossAxisSpacing:12,mainAxisSpacing:12),
        itemBuilder:(_,i)=>_tile(Column(mainAxisAlignment:MainAxisAlignment.center,children:[
          Icon(icons[i],size:42,color:colors[i]),const SizedBox(height:8),
          Text(labels[i],style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800))
        ]),()=>i==target?_win(2,'إجابة صحيحة'):setState(()=>feedback='اختيار غير صحيح'),i)),
    ]);
  }

  Widget _quiz() {
    const q = <GameType,List<String>>{
      GameType.trueFalse:['صحيح','خطأ','صحيح','خطأ'],GameType.flagQuiz:['اليمن','اليابان','البرازيل','فرنسا'],
      GameType.animalQuiz:['فهد','حوت','نسر','فيل'],GameType.foodQuiz:['بيتزا','سوشي','سلطة','نودلز'],
      GameType.geographyQuiz:['آسيا','أفريقيا','أوروبا','أمريكا الجنوبية'],GameType.scienceQuiz:['الماء','الأكسجين','الحديد','الكربون'],
      GameType.historyQuiz:['القديمة','الوسطى','الحديثة','المعاصرة'],GameType.languageQuiz:['اسم','فعل','حرف','صفة'],
    };
    return Column(children:[_head(),const SizedBox(height:18),_grid(q[widget.type] ?? const ['A','B','C','D'])]);
  }

  Widget _word() {
    const words=['نجمة','بحر','صحة','لعبة','مغامرة'];
    final w=words[(round-1)%words.length];
    final chars=w.runes.map(String.fromCharCode).toList()..shuffle(_r);
    return Column(children:[_head(),const SizedBox(height:18),
      Text(chars.join(' • '),style:const TextStyle(fontSize:27,fontWeight:FontWeight.w900)),
      const SizedBox(height:18),_tile(const Center(child:Text('حل الكلمة',style:TextStyle(fontWeight:FontWeight.w800))),()=>_win(2,'الكلمة: $w'),1)]);
  }

  Widget _tapChallenge(String title, IconData icon, {int goal = 8}) => Column(
    children: [
      _head(),
      Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 18),
      AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) => Transform.scale(
          scale: 1 + _pulse.value * .06,
          child: child,
        ),
        child: Material(
          color: colors[target],
          shape: const CircleBorder(),
          elevation: 10,
          child: InkWell(
            onTap: () {
              setState(() => _tapCount++);
              if (_tapCount >= goal) _win(4, 'تحدٍ مكتمل');
            },
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 150,
              height: 150,
              child: Icon(icon, size: 64, color: Colors.white),
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      Text(
        '$_tapCount / $goal',
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
      ),
    ],
  );

  Widget _body() {
    switch(widget.type) {
      case GameType.colorRush: return _arena(mode:'color');
      case GameType.higherLower: return Column(children:[_head(),const SizedBox(height:18),const Text('هل الرقم التالي أعلى أم أقل؟',style:TextStyle(fontSize:21)),_grid(const ['أعلى','أقل','متساوي','مفاجأة'])]);
      case GameType.numberGuess: return Column(children:[_head(),const SizedBox(height:18),const Text('اختر الرقم الأقرب للهدف المخفي',style:TextStyle(fontSize:20)),_grid(const ['3','7','12','18'])]);
      case GameType.wordScramble: case GameType.anagramBattle: case GameType.wordGuess: return _word();
      case GameType.emojiMemory: case GameType.cardFlip: case GameType.connectPairs: return Column(children:[_head(),const SizedBox(height:15),_memory()]);
      case GameType.patternTap: case GameType.sequenceRecall: return Column(children:[_head(),Text(pattern.map((x)=>['A','B','C','D'][x]).join(' '),style:const TextStyle(fontSize:32)),const SizedBox(height:12),_arena()]);
      case GameType.oddOneOut: return Column(children:[_head(),_grid(const ['●','●','●','◆'])]);
      case GameType.treasureHunt: return Column(children:[_head(),_grid(const ['الخريطة','الشاطئ','الجوهرة','البوابة'])]);
      case GameType.mathDuel: return Column(children:[_head(),const Text('7 × 3 + 3 = ؟',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900)),_grid(const ['21','24','27','30'])]);
      case GameType.codeBreaker: return Column(children:[_head(),const Text('اختر الشفرة المضيئة',style:TextStyle(fontSize:20)),_grid(const ['123','314','721','909'])]);
      case GameType.shapeMatch: return _arena(mode:'shape');
      case GameType.colorMatch: return _arena(mode:'color');
      case GameType.lightSwitch: return Column(children:[_head(),_grid(const ['تشغيل','إيقاف','تشغيل','إيقاف'])]);
      case GameType.reactionRace: return _tapChallenge('سباق رد الفعل',Icons.bolt_rounded);
      case GameType.targetHit: return _tapChallenge('التصويب على الهدف',Icons.adjust_rounded,goal:5);
      case GameType.bubblePop: return _tapChallenge('فرقعة الفقاعات',Icons.circle_rounded,goal:10);
      case GameType.stackTower: return _tapChallenge('بناء البرج',Icons.account_balance_rounded,goal:6);
      case GameType.mazeRunner: return _grid(const ['البداية','ممر 1','ممر 2','ممر 3','البوابة','المخرج']);
      case GameType.fourInRow: return _grid(const ['عمود 1','عمود 2','عمود 3','عمود 4','عمود 5','عمود 6','عمود 7']);
      case GameType.dotsAndBoxes: return _grid(const ['مربع 1','مربع 2','مربع 3','مربع 4','مربع 5','مربع 6','مربع 7','مربع 8','مربع 9']);
      case GameType.fastChoice: return _tapChallenge('اختيار سريع',Icons.flash_on_rounded,goal:5);
      case GameType.picturePuzzle: return _grid(const ['قطعة A','قطعة B','قطعة C','قطعة D']);
      case GameType.balanceBeam: return _tapChallenge('توازن الشعاع',Icons.balance_rounded,goal:7);
      case GameType.rocketRace: return _tapChallenge('سباق الصاروخ',Icons.rocket_launch_rounded,goal:8);
      case GameType.galaxyCatch: return _tapChallenge('التقاط النجوم',Icons.auto_awesome_rounded,goal:9);
      case GameType.rhythmTap: return _tapChallenge('النقر مع الإيقاع',Icons.music_note_rounded,goal:12);
      case GameType.riddleRush: return Column(children:[_head(),const Text('شيء يسمع بلا أذن ويتكلم بلا لسان؟',style:TextStyle(fontSize:21),textAlign:TextAlign.center),_grid(const ['الصدى','الظل','الوقت','المفتاح'])]);
      default: return _quiz();
    }
  }

  @override Widget build(BuildContext context)=>Directionality(
    textDirection:TextDirection.rtl,
    child:SingleChildScrollView(padding:const EdgeInsets.fromLTRB(16,18,16,100),child:_body()),
  );
}
