import 'package:flutter/material.dart';
import 'package:memochat/features/games/models/game.dart';
import 'game_art.dart';

class GameCard extends StatelessWidget {
  final GameDefinition game; final int index; final VoidCallback onTap;
  const GameCard({super.key,required this.game,required this.index,required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // The games sheet can contain dozens of cards. Avoid starting an
    // independent animation for every visible card when the sheet opens;
    // that can cause a long first-frame stall on low-memory devices.
    return RepaintBoundary(child: _card(context, dark));
  }

  Widget _card(BuildContext context,bool dark)=>Material(
    color:dark?const Color(0xFF17212B):Colors.white,borderRadius:BorderRadius.circular(18),
    child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(18),
      child:Padding(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Container(width:42,height:42,alignment:Alignment.center,decoration:BoxDecoration(color:Theme.of(context).colorScheme.primaryContainer,borderRadius:BorderRadius.circular(14)),child:GameArt(type:game.type,size:42,compact:true),),
        const Spacer(),Text(game.title,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:13)),
        const SizedBox(height:3),Text(game.playersLabel,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(fontSize:10,color:dark?Colors.white60:Colors.black54)),
        const SizedBox(height:2),Text(game.durationLabel,style:TextStyle(fontSize:10,color:dark?Colors.white38:Colors.black45)),
      ])),
    ),
  );
}
