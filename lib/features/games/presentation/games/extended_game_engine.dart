import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/game_leaderboard_service.dart';
import '../../services/game_achievement_service.dart';

class ExtendedGameConfig {
  final String title,instruction;
  final List<String> options;
  final int correctIndex;
  const ExtendedGameConfig({required this.title,required this.instruction,required this.options,required this.correctIndex});
}

class ExtendedGameEngine extends StatefulWidget {
  final ExtendedGameConfig config;
  const ExtendedGameEngine({super.key,required this.config});
  @override State<ExtendedGameEngine> createState()=>_ExtendedGameEngineState();
}
class _ExtendedGameEngineState extends State<ExtendedGameEngine>{
  final _r=Random();Timer? _timer;int _seconds=45,_score=0,_round=1;bool _started=false,_paused=false,_finished=false;late List<String> _options;
  @override void initState(){super.initState();_shuffle();}
  void _shuffle(){_options=List.of(widget.config.options)..shuffle(_r);}
  void _start(){setState(()=>_started=true);_timer=Timer.periodic(const Duration(seconds:1),(_){if(!mounted||_paused)return;if(_seconds<=1)_finish();else setState(()=>_seconds--);});}
  Future<void> _finish() async { _timer?.cancel(); try { await GameLeaderboardService.instance.submitScore(gameId: widget.config.title, score: _score); if (_score >= 10) await GameAchievementService.instance.unlock('score_10_${widget.config.title}'); } catch (_) {} if(mounted)setState(()=>_finished=true); }
  void _answer(String v){if(!_started||_paused||_finished)return;final ok=v==widget.config.options[widget.config.correctIndex];setState((){if(ok)_score+=2;_round++;_seconds=max(0,_seconds-1);});if(_seconds==0)_finish();else _shuffle();}
  void _replay(){_timer?.cancel();setState((){_seconds=45;_score=0;_round=1;_started=false;_paused=false;_finished=false;_shuffle();});}
  @override void dispose(){_timer?.cancel();super.dispose();}
  @override Widget build(BuildContext context){
    if(!_started)return Scaffold(appBar:AppBar(title:Text(widget.config.title)),body:_startView());
    if(_finished)return Scaffold(appBar:AppBar(title:Text(widget.config.title)),body:_resultView());
    return Scaffold(appBar:AppBar(title:Text(widget.config.title),actions:[IconButton(onPressed:()=>setState(()=>_paused=!_paused),icon:Icon(_paused?Icons.play_arrow:Icons.pause))]),body:Stack(children:[ListView(padding:const EdgeInsets.all(18),children:[Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text('النقاط: $_score',style:const TextStyle(fontWeight:FontWeight.w800)),Text('الجولة $_round'),Text('$_seconds ث',style:TextStyle(fontWeight:FontWeight.w800,color:_seconds<=10?Theme.of(context).colorScheme.error:null))]),const SizedBox(height:24),Text(widget.config.instruction,textAlign:TextAlign.center,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800)),const SizedBox(height:20),..._options.map((o)=>Padding(padding:const EdgeInsets.only(bottom:10),child:FilledButton(onPressed:()=>_answer(o),child:Padding(padding:const EdgeInsets.all(12),child:Text(o))))) ]),if(_paused)ColoredBox(color:Colors.black54,child:Center(child:Card(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.pause_circle,size:52),const Text('متوقف مؤقتاً'),FilledButton(onPressed:()=>setState(()=>_paused=false),child:const Text('متابعة'))]))))) ]));
  }
  Widget _startView()=>Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.sports_esports,size:64),Text(widget.config.instruction,textAlign:TextAlign.center,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w800)),const SizedBox(height:24),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:_start,icon:const Icon(Icons.play_arrow),label:const Text('بدء اللعبة')))])));
  Widget _resultView()=>Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.emoji_events,size:64),const Text('النتيجة النهائية',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900)),Text('$_score نقطة',style:const TextStyle(fontSize:30)),const SizedBox(height:20),FilledButton.icon(onPressed:_replay,icon:const Icon(Icons.replay),label:const Text('إعادة اللعب'))])));
}