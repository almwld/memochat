import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:memochat/features/chat/services/chat_service.dart';
import 'package:memochat/features/chat/services/call_service.dart';
import 'package:memochat/features/chat/services/toast_service.dart';
import 'package:memochat/features/chat/models/call_model.dart';
import 'package:memochat/features/chat/presentation/chat_room_screen.dart';
import 'package:memochat/features/chat/presentation/call_screen.dart';

class ChatNavigation {
  static Future<void> openChat(BuildContext context,{required String userName,required String userId,String? userImage}) async {
    final user=FirebaseAuth.instance.currentUser;
    if(user==null){await ToastService.showError('يجب تسجيل الدخول أولاً');return;}
    if(userId.trim().isEmpty||userId==user.uid){await ToastService.showError('معرّف المستخدم الآخر غير صالح');return;}
    try{
      final name=user.displayName?.trim().isNotEmpty==true?user.displayName!.trim():'مستخدم MemoChat';
      final id=await ChatService().createChat(userId:userId.trim(),userName:userName.trim().isEmpty?'مستخدم':userName.trim(),currentUserName:name,userImage:userImage,currentUserImage:user.photoURL);
      if(!context.mounted)return;
      await Navigator.push(context,MaterialPageRoute(builder:(_)=>ChatRoomScreen(chatId:id,otherUserId:userId.trim(),otherUserName:userName.trim().isEmpty?'مستخدم':userName.trim(),groupImage:userImage,isGroup:false)));
    }catch(e){if(context.mounted)await ToastService.showError('فشل فتح المحادثة: $e');}
  }
  static Future<void> openCall(BuildContext context,{required String chatId,required String userName,required String userId,required bool isVideo}) async {
    final user=FirebaseAuth.instance.currentUser;
    if(user==null||chatId.trim().isEmpty||userId.trim().isEmpty||userId==user.uid){if(context.mounted)await ToastService.showError('بيانات المكالمة غير صالحة');return;}
    try{
      final call=await CallService().initiateCall(chatId:chatId,receiverId:userId,receiverName:userName,type:isVideo?CallType.video:CallType.audio);
      if(!context.mounted||call==null)return;
      await Navigator.push(context,MaterialPageRoute(builder:(_)=>CallScreen(chatId:chatId,userName:userName,userId:userId,callId:call.id,isVideo:isVideo,isOutgoing:true)));
    }catch(e){if(context.mounted)await ToastService.showError('فشل بدء المكالمة: $e');}
  }
}