import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:memochat/features/chat/services/chat_service.dart';
import 'package:memochat/features/chat/services/call_service.dart';
import 'package:memochat/features/chat/services/active_call_registry.dart';
import 'package:memochat/features/chat/services/toast_service.dart';
import 'package:memochat/features/chat/models/call_model.dart';
import 'package:memochat/features/chat/presentation/chat_room_screen.dart';
import 'package:memochat/features/chat/presentation/call_screen.dart';

class ChatNavigation {
  static final Set<String> _openingRooms = <String>{};
  static final Map<String, DateTime> _recentlyOpenedRooms = <String, DateTime>{};
  static Future<void> openRoom(BuildContext context,{required String chatId,required String otherUserId,required String otherUserName,String? otherUserImage,bool isGroup=false,String? groupImage,String? lastMessage}) async {
    final id=chatId.trim();
    if(id.isEmpty||_openingRooms.contains(id)) return;
    final now=DateTime.now();
    final last=_recentlyOpenedRooms[id];
    if(last != null && now.difference(last) < const Duration(seconds: 3)) return;
    _openingRooms.add(id);
    _recentlyOpenedRooms[id]=now;
    try{
      if(!context.mounted)return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        settings: RouteSettings(name: '/chat/$id'),
        builder:(_)=>ChatRoomScreen(
          chatId:id,otherUserId:otherUserId,otherUserName:otherUserName,otherUserImage:otherUserImage,
          isGroup:isGroup,groupImage:groupImage,lastMessage:lastMessage,
        ),
      ));
    } finally { _openingRooms.remove(id); }
  }

  static final Set<String> _openingUsers = <String>{};
  static Future<void> openChat(BuildContext context,{required String userName,required String userId,String? userImage}) async {
    final user=FirebaseAuth.instance.currentUser;
    if(user==null){ToastService.showError('يجب تسجيل الدخول أولاً');return;}
    final requestedId=userId.trim();
    if(requestedId.isEmpty||requestedId==user.uid){ToastService.showError('معرّف المستخدم الآخر غير صالح');return;}
    if(_openingUsers.contains(requestedId)) return;
    _openingUsers.add(requestedId);
    try{
      var resolvedId=requestedId;
      // Social/profile surfaces may expose the public Memo ID instead of the
      // Firebase UID. Resolve it before creating/opening the canonical DM.
      if(resolvedId.startsWith('memo_')){
        final snap=await FirebaseFirestore.instance.collection('users').where('publicId',isEqualTo:resolvedId).limit(1).get();
        if(snap.docs.isNotEmpty) resolvedId=snap.docs.first.id;
      }
      if(resolvedId.isEmpty||resolvedId==user.uid){
        if(context.mounted) ToastService.showError('حساب المستخدم غير صالح');
        return;
      }
      final name=user.displayName?.trim().isNotEmpty==true?user.displayName!.trim():'مستخدم MemoChat';
      final displayName=userName.trim().isEmpty?'مستخدم':userName.trim();
      final id=await ChatService().createChat(userId:resolvedId,userName:displayName,currentUserName:name,userImage:userImage,currentUserImage:user.photoURL);
      if(!context.mounted)return;
      await openRoom(context,chatId:id,otherUserId:resolvedId,otherUserName:displayName,otherUserImage:userImage,groupImage:userImage,isGroup:false);
    }catch(e){if(context.mounted)ToastService.showError('فشل فتح المحادثة: $e');}
    finally { _openingUsers.remove(requestedId); }
  }
  static Future<void> openCall(BuildContext context,{required String chatId,required String userName,required String userId,required bool isVideo}) async {
    final user=FirebaseAuth.instance.currentUser;
    if(user==null||chatId.trim().isEmpty||userId.trim().isEmpty||userId==user.uid){if(context.mounted)ToastService.showError('بيانات المكالمة غير صالحة');return;}
    if (ActiveCallRegistry.instance.hasActiveCall) {
      if (context.mounted) ToastService.showError('لديك مكالمة نشطة بالفعل');
      return;
    }
    try{
      final call=await CallService().initiateCall(chatId:chatId,receiverId:userId,receiverName:userName,type:isVideo?CallType.video:CallType.audio);
      if(!context.mounted||call==null)return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder:(_)=>CallScreen(
          chatId:chatId,
          userName:userName,
          userId:userId,
          callId:call.id,
          isVideo:isVideo,
          isOutgoing:true,
        ),
      ));
    }catch(e){
      if(context.mounted)ToastService.showError('فشل بدء المكالمة: $e');
    }
  }
}