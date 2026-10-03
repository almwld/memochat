import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:memochat/features/games/models/game.dart';
import 'package:memochat/features/games/models/game_session.dart';
import 'package:memochat/features/games/services/game_service.dart';

class GameRoomScreen extends StatelessWidget {
  final String chatId; final String gameId;
  const GameRoomScreen({super.key,required this.chatId,required this.gameId});

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('غرفة اللعبة'),centerTitle:true),
    body:StreamBuilder<GameSession?>(
      stream:GameService.instance.watchGame(chatId,gameId),
      builder:(context,snapshot){
        final game=snapshot.data;
        if(snapshot.connectionState==ConnectionState.waiting) return const Center(child:CircularProgressIndicator());
        if(game==null) return const Center(child:Text('لم تعد جلسة اللعبة متاحة.'));
        final uid=FirebaseAuth.instance.currentUser?.uid;
        final joined=uid!=null&&game.players.contains(uid);
        return Padding(padding:const EdgeInsets.all(20),child:Column(children:[
          const Icon(Icons.sports_esports_rounded,size:54),
          const SizedBox(height:12),
          Text(_title(game),style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900)),
          const SizedBox(height:8),
          Text('${game.players.length} لاعبين',style:Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height:24),
          if(game.status==GameStatus.waiting&&!joined) FilledButton.icon(
            onPressed:uid==null?null:()=>GameService.instance.joinGame(chatId:chatId,gameId:gameId,uid:uid),
            icon:const Icon(Icons.login_rounded),label:const Text('انضم إلى اللعبة'),
          ) else if(game.status==GameStatus.waiting) const Text('بانتظار اللاعبين الآخرين...')
          else if(game.status==GameStatus.playing) const Text('الجلسة جاهزة — سيتم توصيل منطق اللعبة هنا.'),
        ]));
      },
    ),
  );

  String _title(GameSession game)=>game.type.name=='xo'?'إكس أو':'لعبة ${game.type.name}';
}
