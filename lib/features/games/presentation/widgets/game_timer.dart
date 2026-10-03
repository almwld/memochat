import 'dart:async';
import 'package:flutter/material.dart';
class GameTimer extends StatefulWidget {
  final Duration duration; final VoidCallback? onFinished; final bool paused;
  const GameTimer({super.key, required this.duration, this.onFinished, this.paused = false});
  @override State<GameTimer> createState() => _GameTimerState();
}
class _GameTimerState extends State<GameTimer> {
  Timer? _timer; late Duration _remaining = widget.duration;
  @override void initState(){super.initState();_sync();}
  @override void didUpdateWidget(covariant GameTimer old){super.didUpdateWidget(old);if(old.duration!=widget.duration)_remaining=widget.duration;_sync();}
  void _sync(){_timer?.cancel();if(widget.paused||_remaining<=Duration.zero)return;_timer=Timer.periodic(const Duration(seconds:1),(_){if(!mounted)return;if(_remaining<=const Duration(seconds:1)){setState(()=>_remaining=Duration.zero);_timer?.cancel();widget.onFinished?.call();}else{setState(()=>_remaining-=const Duration(seconds:1));}});}
  @override void dispose(){_timer?.cancel();super.dispose();}
  @override Widget build(BuildContext context){final s=_remaining.inSeconds;return Text('${(s~/60).toString().padLeft(2,'0')}:${(s%60).toString().padLeft(2,'0')}',style:TextStyle(fontWeight:FontWeight.w800,color:s<=10?Theme.of(context).colorScheme.error:null));}
}