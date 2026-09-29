import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../../core/calls/livekit_token_service.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key,required this.chatId,required this.otherUserId,required this.otherUserName,this.otherUserImage,required this.isVideo});
  final String chatId,otherUserId,otherUserName; final String? otherUserImage; final bool isVideo;
  @override State<CallScreen> createState()=>_CallScreenState();
}
class _CallScreenState extends State<CallScreen>{
  final _token=const LiveKitTokenService(); final _db=FirebaseFirestore.instance; Room? _room; Timer? _timer; String? _callId,_error; bool _connecting=true,_muted=false,_camera=true,_speaker=true; int _seconds=0;
  @override void initState(){super.initState();_start();}
  Future<void> _start() async{
    try{
      final uid=FirebaseAuth.instance.currentUser?.uid;if(uid==null)throw StateError('يرجى تسجيل الدخول');
      final ref=_db.collection('calls').doc();_callId=ref.id;final roomName='call_\${ref.id}';
      await ref.set({'callId':ref.id,'chatId':widget.chatId,'callerId':uid,'receiverId':widget.otherUserId,'callerName':FirebaseAuth.instance.currentUser?.displayName??'مستخدم','callerPhotoUrl':FirebaseAuth.instance.currentUser?.photoURL??'','isVideo':widget.isVideo,'callType':widget.isVideo?'video':'audio','status':'calling','roomName':roomName,'liveKitRoomName':roomName,'createdAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp()});
      final issued=await _token.issue(roomName:roomName,participantName:FirebaseAuth.instance.currentUser?.displayName??'مستخدم');
      final room=Room(roomOptions:const RoomOptions(adaptiveStream:true,dynacast:true));await room.connect(issued.serverUrl,issued.token);await room.localParticipant?.setMicrophoneEnabled(true);if(widget.isVideo)await room.localParticipant?.setCameraEnabled(true);
      if(!mounted){await room.disconnect();return;}setState(()=>{_room=room;_connecting=false;_camera=widget.isVideo;});await ref.update({'status':'connected','connectedAt':FieldValue.serverTimestamp()});_timer=Timer.periodic(const Duration(seconds:1),(_){if(mounted)setState(()=>_seconds++);});
    }catch(e){if(mounted)setState(()=>{_connecting=false;_error=e.toString();});}
  }
  Future<void> _mute()async{final p=_room?.localParticipant;if(p==null)return;final n=!_muted;await p.setMicrophoneEnabled(!n);if(mounted)setState(()=>_muted=n);}
  Future<void> _cameraToggle()async{final p=_room?.localParticipant;if(p==null||!widget.isVideo)return;final n=!_camera;await p.setCameraEnabled(n);if(mounted)setState(()=>_camera=n);}
  Future<void> _end()async{if(_callId!=null)await _db.collection('calls').doc(_callId).set({'status':'ended','endedAt':FieldValue.serverTimestamp()},SetOptions(merge:true));_timer?.cancel();final r=_room;if(r!=null)await r.disconnect();if(mounted)Navigator.pop(context);}
  @override void dispose(){_timer?.cancel();final r=_room;if(r!=null)unawaited(r.disconnect());super.dispose();}
  String _time(){final m=(_seconds~/60).toString().padLeft(2,'0');final s=(_seconds%60).toString().padLeft(2,'0');return '\$m:\$s';}
  @override Widget build(BuildContext context)=>Scaffold(backgroundColor:const Color(0xFF081012),body:SafeArea(child:Stack(children:[
    if(_room!=null)Positioned.fill(child:_remoteView()),
    if(_connecting)const Center(child:CircularProgressIndicator(color:Color(0xFF0A8F83))),
    if(_error!=null)Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.error_outline,color:Colors.white70,size:56),const SizedBox(height:12),const Text('تعذر بدء الاتصال',style:TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.bold)),const SizedBox(height:8),Text(_error!,style:const TextStyle(color:Colors.white60),textAlign:TextAlign.center),const SizedBox(height:20),FilledButton(onPressed:()=>Navigator.pop(context),child:const Text('عودة'))]))),
    Positioned(top:12,left:12,right:12,child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[IconButton(onPressed:_end,icon:const Icon(Icons.arrow_back_ios_new,color:Colors.white)),Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:8),decoration:BoxDecoration(color:Colors.black45,borderRadius:BorderRadius.circular(24)),child:Text(_room==null?'جاري الاتصال...':_time(),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w600)))])),
    if(_room!=null)Positioned(left:16,right:16,bottom:24,child:Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:8),decoration:BoxDecoration(color:Colors.black54,borderRadius:BorderRadius.circular(32)),child:Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[_button(_muted?Icons.mic_off:Icons.mic,_mute),if(widget.isVideo)_button(_camera?Icons.videocam:Icons.videocam_off,_cameraToggle),_button(_speaker?Icons.volume_up:Icons.volume_off,()=>setState(()=>_speaker=!_speaker)),_button(Icons.call_end,_end,danger:true)]))),
  ])));
  Widget _button(IconData icon,VoidCallback action,{bool danger=false})=>IconButton.filled(onPressed:action,style:IconButton.styleFrom(backgroundColor:danger?Colors.red:Colors.white12,foregroundColor:Colors.white,padding:const EdgeInsets.all(15)),icon:Icon(icon,size:25));
  Widget _remoteView(){final participants=_room!.remoteParticipants.values.toList();if(participants.isEmpty)return Center(child:Column(mainAxisSize:MainAxisSize.min,children:[CircleAvatar(radius:58,backgroundImage:widget.otherUserImage?.isNotEmpty==true?NetworkImage(widget.otherUserImage!):null,child:widget.otherUserImage?.isNotEmpty==true?null:const Icon(Icons.person,size:56)),const SizedBox(height:16),Text(widget.otherUserName,style:const TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.w700)),const SizedBox(height:8),const Text('في انتظار الطرف الآخر...',style:TextStyle(color:Colors.white60))]));final p=participants.first;for(final pub in p.trackPublications.values){final t=pub.track;if(t is VideoTrack)return VideoTrackRenderer(t);}return Center(child:Text(widget.otherUserName,style:const TextStyle(color:Colors.white,fontSize:24)));}
}
