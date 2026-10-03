import 'package:flutter/material.dart';
import '../../models/game.dart';

class GameCard extends StatelessWidget {
  final GameDefinition game; final int index; final VoidCallback onTap;
  const GameCard({super.key,required this.game,required this.index,required this.onTap});

  @override Widget build(BuildContext context){
    final dark=Theme.of(context).brightness==Brightness.dark;
    return RepaintBoundary(child: TweenAnimationBuilder<double>(
      tween:Tween(begin:0,end:1),duration:const Duration(milliseconds:360),
      curve:Curves.easeOutCubic,child:_card(context,dark),
      builder:(context,value,child)=>Transform.translate(offset:Offset(0,18*(1-value)),child:Transform.scale(scale:.94+.06*value,child:FadeTransition(opacity:AlwaysStoppedAnimation<double>(value),child:child))),
    ));
  }

  Widget _card(BuildContext context,bool dark)=>Material(
    color:dark?const Color(0xFF17212B):Colors.white,borderRadius:BorderRadius.circular(18),
    child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(18),
      child:Padding(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Container(width:42,height:42,alignment:Alignment.center,decoration:BoxDecoration(color:Theme.of(context).colorScheme.primaryContainer,borderRadius:BorderRadius.circular(14)),child:Text(game.icon,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w700)),),
        const Spacer(),Text(game.title,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:13)),
        const SizedBox(height:3),Text(game.playersLabel,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(fontSize:10,color:dark?Colors.white60:Colors.black54)),
        const SizedBox(height:2),Text(game.durationLabel,style:TextStyle(fontSize:10,color:dark?Colors.white38:Colors.black45)),
      ])),
    ),
  );
}
