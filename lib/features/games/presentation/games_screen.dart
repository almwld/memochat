import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../data/games_catalog.dart';
import 'package:memochat/features/chat/services/chat_service.dart';
import 'package:memochat/features/games/models/game.dart';
import '../services/game_service.dart';
import 'game_room_screen.dart';
import 'game_play_screen.dart';
import '../services/game_challenge_service.dart';
import 'widgets/game_grid.dart';
import 'widgets/game_art.dart';

class GamesScreen extends StatefulWidget {
  final String chatId;
  const GamesScreen({super.key,required this.chatId});
  @override State<GamesScreen> createState()=>_GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  GameTimeLimit _limit=GameTimeLimit.none;
  bool _opening=false;

  Future<void> _openGame(int index) async {
    if (_opening) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || index < 0 || index >= GamesCatalog.all.length) return;
    final definition = GamesCatalog.all[index];
    setState(() => _opening = true);

    // Open the game UI first. Multiplayer persistence/invites are optional and
    // must never prevent a game from opening when Firestore is slow/restricted.
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GamePlayScreen(
            type: definition.type,
            title: definition.title,
            chatId: widget.chatId,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }

    // Persist the session and invitation after the UI is available.
    try {
      final id = await GameService.instance.createGame(
        chatId: widget.chatId,
        type: definition.type,
        uid: uid,
        timeLimit: _limit,
      ).timeout(const Duration(seconds: 4));
      try {
        final chat = await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).get();
        final participants = (chat.data()?['participants'] as List?)?.map((value) => value.toString()).toList() ?? const <String>[];
        final opponents = participants.where((participant) => participant != uid).toSet();
        final challengeIds = <String>[];
        for (final opponent in opponents) {
          try {
            final challengeId = await GameChallengeService.instance.create(
              gameId: id,
              opponentUid: opponent,
              chatId: widget.chatId,
              gameType: definition.type.name,
            );
            if (challengeId != null) challengeIds.add(challengeId);
          } catch (error) {
            debugPrint('Signal game challenge unavailable: $error');
          }
        }
        await ChatService().sendMessage(
          chatId: widget.chatId,
          text: '${definition.title} — دعوة تحدٍ مباشرة مشفرة',
          metadata: {
            'kind': 'signal_game_challenge',
            'gameId': id,
            'gameType': definition.type.name,
            'timeLimit': _limit.name,
            'challengeIds': challengeIds,
          },
        ).timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('game invite unavailable: $e');
      }
    } catch (e) {
      debugPrint('game session persistence unavailable: $e');
    }
  }

  @override Widget build(BuildContext context){
    final dark=Theme.of(context).brightness==Brightness.dark;
    return SafeArea(child:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(18,8,18,4),child:Row(children:[
        Container(width:44,height:44,decoration:BoxDecoration(color:Theme.of(context).colorScheme.primaryContainer,borderRadius:BorderRadius.circular(15)),child:GameArt(type: GameType.xo, size: 44, compact: true)),
        const SizedBox(width:12),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('ألعاب الدردشة',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900)),Text('اختر لعبة وابدأ التحدي',style:TextStyle(fontSize:12))])),
        IconButton(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.close_rounded)),
      ])),
      Padding(padding:const EdgeInsets.symmetric(horizontal:14,vertical:5),child:DropdownButtonFormField<GameTimeLimit>(
        value:_limit,onChanged:(v)=>setState(()=>_limit=v??GameTimeLimit.none),
        decoration:InputDecoration(labelText:'المدة الاختيارية',filled:true,fillColor:dark?const Color(0xFF17212B):const Color(0xFFF4F7F7),border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:BorderSide.none)),
        items:GameTimeLimit.values.map((e)=>DropdownMenuItem(value:e,child:Text(e.label))).toList(),
      )),
      const SizedBox(height:4),
      Expanded(child:GameGrid(onGameTap:_openGame)),
    ]));
  }
}

Future<void> showGamesSheet(BuildContext context,{required String chatId}) async {
  await showModalBottomSheet<void>(
    context:context,isScrollControlled:true,showDragHandle:false,backgroundColor:Colors.transparent,
    sheetAnimationStyle:AnimationStyle(duration:Duration(milliseconds:280),reverseDuration:Duration(milliseconds:220)),
    builder:(_)=>DraggableScrollableSheet(initialChildSize:.82,minChildSize:.55,maxChildSize:.95,expand:false,builder:(_,controller)=>ClipRRect(borderRadius:const BorderRadius.vertical(top:Radius.circular(28)),child:Material(color:Theme.of(context).scaffoldBackgroundColor,child:GamesScreen(chatId:chatId)))),
  );
}
