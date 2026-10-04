import 'package:flutter/material.dart';
import '../../data/games_catalog.dart';
import 'game_card.dart';

class GameGrid extends StatelessWidget {
  final ValueChanged<int> onGameTap;
  const GameGrid({super.key,required this.onGameTap});
  @override Widget build(BuildContext context)=>GridView.builder(
    padding:const EdgeInsets.fromLTRB(14,8,14,28),
    physics:const BouncingScrollPhysics(),
    gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:3,crossAxisSpacing:8,mainAxisSpacing:8,childAspectRatio:.78),
    itemCount:GamesCatalog.all.length,
    itemBuilder:(context,index)=>GameCard(game:GamesCatalog.all[index],index:index,onTap:()=>onGameTap(index)),
  );
}
