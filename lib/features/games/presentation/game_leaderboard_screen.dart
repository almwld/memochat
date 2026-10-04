import 'package:flutter/material.dart';
import '../services/game_leaderboard_service.dart';

class GameLeaderboardScreen extends StatelessWidget {
  final String gameId; final String title;
  const GameLeaderboardScreen({super.key,required this.gameId,required this.title});
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(title),centerTitle:true),
    body:StreamBuilder(
      stream:GameLeaderboardService.instance.watchBest(gameId),
      builder:(context,snapshot){
        if(snapshot.hasError)return const Center(child:Text('تعذر تحميل لوحة المتصدرين'));
        if(!snapshot.hasData)return const Center(child:CircularProgressIndicator());
        final docs=snapshot.data!.docs;
        if(docs.isEmpty)return const Center(child:Text('لا توجد نتائج بعد'));
        return ListView.separated(
          padding:const EdgeInsets.all(16),itemCount:docs.length,separatorBuilder:(_,__)=>const SizedBox(height:8),
          itemBuilder:(_,i){final d=docs[i].data();final score=(d['score'] as num?)?.toInt()??0;return ListTile(
            leading:CircleAvatar(child:Text('${i+1}')),title:Text('لاعب ${d['uid']??''}',maxLines:1,overflow:TextOverflow.ellipsis),
            trailing:Text('$score',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)));},
        );
      },
    ),
  );
}