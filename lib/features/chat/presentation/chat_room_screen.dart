// ignore_for_file: prefer_interpolation_to_compose_strings
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/offline/pending_message_queue.dart';
import '../../../core/media/nextcloud_media_service.dart';
import '../../calls/presentation/call_screen.dart';

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({super.key,required this.chatId,required this.otherUserId,required this.otherUserName,this.otherUserImage});
  final String chatId,otherUserId,otherUserName; final String? otherUserImage;
  @override State<ChatRoomScreen> createState()=>_ChatRoomScreenState();
}
class _ChatRoomScreenState extends State<ChatRoomScreen> with WidgetsBindingObserver{
  final _pending=PendingMessageQueue();
  final _text=TextEditingController();final _scroll=ScrollController();final _db=FirebaseFirestore.instance;final _media=const NextcloudMediaService();Timer? _typingTimer;bool _typing=false,_uploading=false;Map<String,dynamic>? _reply;
  String get _uid=>FirebaseAuth.instance.currentUser?.uid??'';
  CollectionReference<Map<String,dynamic>> get _messages=>_db.collection('chats').doc(widget.chatId).collection('messages');
  Future<void> _flushPending() async {await _pending.flush((message) async {final ref=_messages.doc(message.id);await ref.set({'chatId':widget.chatId,'senderId':_uid,'senderName':FirebaseAuth.instance.currentUser?.displayName??'مستخدم','text':message.text,'type':'text','status':'sent','timestamp':Timestamp.fromDate(message.createdAt),'clientTimestamp':message.createdAt.microsecondsSinceEpoch});});}
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);_text.addListener(_onText);_flushPending();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed)_flushPending();}
  void _onText(){if(_text.text.isNotEmpty&&!_typing)_setTyping(true);_typingTimer?.cancel();_typingTimer=Timer(const Duration(seconds:2),()=>_setTyping(false));}
  Future<void> _setTyping(bool value)async{if(_typing==value)return;if(mounted)setState(()=>_typing=value);try{await _db.collection('chats').doc(widget.chatId).set({'typing.$_uid':value},SetOptions(merge:true));}catch(_){}}
