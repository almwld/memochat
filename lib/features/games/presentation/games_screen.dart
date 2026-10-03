import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../data/games_catalog.dart';
import '../models/game.dart';
import '../services/game_service.dart';
import 'game_room_screen.dart';
import 'widgets/game_grid.dart';

class GamesScreen extends StatefulWidget {
  final String chatId;
  const GamesScreen({super.key,required this.chatId});
  @override State<GamesScreen> createState()=>_GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  GameTimeLimit _limit=GameTimeLimit.none;
  bool _opening=false;

  Future<void> _openGame(int index) async {
    if(_opening) return;
    final uid=FirebaseAuth.instance.currentUser?.uid;
    if(uid==null) return;
    setState(()=>_opening=true);
    try {
      final id=await GameService.instance.createGame(chatId:widget.chatId,type:GamesCatalog.all[index].type,uid:uid,timeLimit:_limit);
      if(!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder:(_)=>GameRoomScreen(chatId:widget.chatId,gameId:id)));
    } finally { if(mounted) setState(()=>_opening=false); }
  }

  @override Widget build(BuildContext context){
    final dark=Theme.of(context).brightness==Brightness.dark;
    return SafeArea(child:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(18,8,18,4),child:Row(children:[
        Container(width:44,height:44,decoration:BoxDecoration(color:Theme.of(context).colorScheme.primaryContainer,borderRadius:BorderRadius.circular(15)),child:const Icon(Icons.sports_esports_rounded)),
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
    transitionAnimationController:AnimationController(vsync:Navigator.of(context),duration:const Duration(milliseconds:280)),
    builder:(_)=>DraggableScrollableSheet(initialChildSize:.82,minChildSize:.55,maxChildSize:.95,expand:false,builder:(_,controller)=>ClipRRect(borderRadius:const BorderRadius.vertical(top:Radius.circular(28)),child:Material(color:Theme.of(context).scaffoldBackgroundColor,child:GamesScreen(chatId:chatId)))),
  );
}
