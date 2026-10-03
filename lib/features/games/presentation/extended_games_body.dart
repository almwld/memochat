import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/game.dart';
import '../services/game_service.dart';

class ExtendedGamesBody extends StatefulWidget {
  final GameType type;
  final String title;
  final String chatId;
  const ExtendedGamesBody({super.key, required this.type, required this.title, required this.chatId});
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

  static const colors = [Color(0xFF10B9A6), Color(0xFF4C7DFF), Color(0xFFFFB84D), Color(0xFFEF6B8A), Color(0xFF8B6CFF)];

  @override void initState() { super.initState(); _newRound(); _findGame(); }
  @override void dispose() { _pulse.dispose(); super.dispose(); }

  Future<void> _findGame() async {
    try {
      final s = await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('games')
        .where('type', isEqualTo: widget.type.name).orderBy('createdAt', descending: true).limit(1).get();
      if (s.docs.isNotEmpty && mounted) setState(() => gameId = s.docs.first.id);
    } catch (_) {}
  }

  void _newRound() {
    target = _r.nextInt(4);
    pattern = List.generate(5, (_) => _r.nextInt(4));
    cards = ['🍎','🚀','🌙','🎵','⚽','🍀','⭐','🐳']..shuffle(_r);
    open.clear();
    feedback = 'اختر الحركة الصحيحة';
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

  void _win([int points = 2, String text = 'رائع! ✨']) {
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
    Text(_icon(), style: const TextStyle(fontSize: 52)),
    const SizedBox(height: 6),
    Text(widget.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
    Text('الجولة $round  •  النقاط $score', style: const TextStyle(fontWeight: FontWeight.w700)),
    const SizedBox(height: 6), Text(feedback, textAlign: TextAlign.center),
  ]);

  String _icon() {
    const m = <GameType,String>{
      GameType.colorRush:'🎨',GameType.higherLower:'↕️',GameType.numberGuess:'🔢',GameType.wordScramble:'🔤',
      GameType.emojiMemory:'🧠',GameType.patternTap:'🔷',GameType.oddOneOut:'👀',GameType.fourInRow:'🟡',
      GameType.dotsAndBoxes:'▫️',GameType.reactionRace:'⚡',GameType.cardFlip:'🃏',GameType.treasureHunt:'💎',
      GameType.mazeRunner:'🌀',GameType.stackTower:'🏗️',GameType.targetHit:'🎯',GameType.bubblePop:'🫧',
      GameType.colorMatch:'🌈',GameType.shapeMatch:'🔺',GameType.sequenceRecall:'🧩',GameType.fastChoice:'🚀',
      GameType.trueFalse:'✅',GameType.flagQuiz:'🏳️',GameType.animalQuiz:'🦊',GameType.foodQuiz:'🍕',
      GameType.geographyQuiz:'🌍',GameType.scienceQuiz:'🔬',GameType.historyQuiz:'🏛️',GameType.languageQuiz:'🗣️',
      GameType.riddleRush:'🧠',GameType.anagramBattle:'🔠',GameType.mathDuel:'➗',GameType.codeBreaker:'🔐',
      GameType.lightSwitch:'💡',GameType.connectPairs:'🔗',GameType.wordGuess:'📝',GameType.picturePuzzle:'🖼️',
      GameType.balanceBeam:'⚖️',GameType.rocketRace:'🚀',GameType.galaxyCatch:'🌌',GameType.rhythmTap:'🎵',
    };
    return m[widget.type] ?? '🎮';
  }

  Widget _grid(List<String> labels) => GridView.builder(
    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: labels.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2,crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:1.5),
    itemBuilder: (_,i) => _tile(Center(child: Text(labels[i],textAlign:TextAlign.center,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w800))), () {
      final correct = i == target;
      if (correct) _win(); else setState(() => feedback = 'حاول مرة أخرى 👀');
    }, i),
  );

  Widget _memory() => GridView.builder(
    shrinkWrap:true, physics:const NeverScrollableScrollPhysics(), itemCount:8,
    gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:4,crossAxisSpacing:8,mainAxisSpacing:8),
    itemBuilder:(_,i)=>_tile(Center(child:Text(open.contains(i)?cards[i]:'❔',style:const TextStyle(fontSize:27))),(){
      if(open.contains(i)) return;
      setState(()=>open.add(i));
      if(open.length==2){
        final a=open.elementAt(0),b=open.elementAt(1);
        if(cards[a]==cards[b]) _win(3,'زوج متطابق! 💫');
        Future.delayed(const Duration(milliseconds:600),(){if(mounted)setState(open.clear);});
      }
    },i),
  );

  Widget _arena({String mode='num'}) {
    final labels = mode=='color' ? ['🔴 أحمر','🟢 أخضر','🔵 أزرق','🟣 بنفسجي']
      : mode=='shape' ? ['▲ مثلث','● دائرة','■ مربع','◆ معين'] : ['①','②','③','④'];
    return Column(children:[_head(),const SizedBox(height:18),_grid(labels)]);
  }

  Widget _quiz() {
    const q = <GameType,List<String>>{
      GameType.trueFalse:['صحيح','خطأ','صحيح','خطأ'],GameType.flagQuiz:['🇾🇪 اليمن','🇯🇵 اليابان','🇧🇷 البرازيل','🇫🇷 فرنسا'],
      GameType.animalQuiz:['🐆 فهد','🐳 حوت','🦅 نسر','🐘 فيل'],GameType.foodQuiz:['🍕 بيتزا','🍣 سوشي','🥗 سلطة','🍜 نودلز'],
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

  Widget _body() {
    switch(widget.type) {
      case GameType.colorRush: return _arena(mode:'color');
      case GameType.higherLower: return Column(children:[_head(),const SizedBox(height:18),const Text('هل الرقم التالي أعلى أم أقل؟',style:TextStyle(fontSize:21)),_grid(const ['⬆️ أعلى','⬇️ أقل','🟰 متساوي','🎲 مفاجأة'])]);
      case GameType.numberGuess: return Column(children:[_head(),const SizedBox(height:18),const Text('اختر الرقم الأقرب للهدف المخفي',style:TextStyle(fontSize:20)),_grid(const ['3','7','12','18'])]);
      case GameType.wordScramble: case GameType.anagramBattle: case GameType.wordGuess: return _word();
      case GameType.emojiMemory: case GameType.cardFlip: case GameType.connectPairs: return Column(children:[_head(),const SizedBox(height:15),_memory()]);
      case GameType.patternTap: case GameType.sequenceRecall: return Column(children:[_head(),Text(pattern.map((x)=>['🔵','🟢','🟣','🟠'][x]).join(' '),style:const TextStyle(fontSize:32)),const SizedBox(height:12),_arena()]);
      case GameType.oddOneOut: return Column(children:[_head(),_grid(const ['●','●','●','◆'])]);
      case GameType.treasureHunt: return Column(children:[_head(),_grid(const ['🗺️','🏝️','💎','🌴'])]);
      case GameType.mathDuel: return Column(children:[_head(),const Text('7 × 3 + 3 = ؟',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900)),_grid(const ['21','24','27','30'])]);
      case GameType.codeBreaker: return Column(children:[_head(),const Text('اختر الشفرة المضيئة',style:TextStyle(fontSize:20)),_grid(const ['123','314','721','909'])]);
      case GameType.shapeMatch: return _arena(mode:'shape');
      case GameType.colorMatch: return _arena(mode:'color');
      case GameType.lightSwitch: return Column(children:[_head(),_grid(const ['💡','🌑','💡','🌑'])]);
      case GameType.reactionRace: case GameType.targetHit: case GameType.bubblePop: case GameType.stackTower:
      case GameType.mazeRunner: case GameType.fourInRow: case GameType.dotsAndBoxes: case GameType.fastChoice:
      case GameType.picturePuzzle: case GameType.balanceBeam: case GameType.rocketRace: case GameType.galaxyCatch:
      case GameType.rhythmTap: return _arena();
      case GameType.riddleRush: return Column(children:[_head(),const Text('شيء يسمع بلا أذن ويتكلم بلا لسان؟',style:TextStyle(fontSize:21),textAlign:TextAlign.center),_grid(const ['الصدى','الظل','الوقت','المفتاح'])]);
      default: return _quiz();
    }
  }

  @override Widget build(BuildContext context)=>Directionality(
    textDirection:TextDirection.rtl,
    child:SingleChildScrollView(padding:const EdgeInsets.fromLTRB(16,18,16,100),child:_body()),
  );
}
