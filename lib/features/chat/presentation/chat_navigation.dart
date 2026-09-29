import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:memochat/features/chat/services/chat_service.dart';
import 'package:memochat/features/chat/services/call_service.dart';
import 'package:memochat/features/chat/services/toast_service.dart';
import 'package:memochat/features/chat/models/call_model.dart';
import 'package:memochat/features/chat/presentation/chat_room_screen.dart';
import 'package:memochat/features/chat/presentation/call_screen.dart';

class ChatNavigation {
  static Future<void> openChat(BuildContext context,{required String doctorName,required String doctorId,String? doctorImage}) async {
    final user=FirebaseAuth.instance.currentUser;
    if(user==null){await ToastService.showError('يجب تسجيل الدخول أولاً');return;}
    if(doctorId.trim().isEmpty||doctorId==user.uid){await ToastService.showError('معرّف المستخدم الآخر غير صالح');return;}
    try{
      final name=user.displayName?.trim().isNotEmpty==true?user.displayName!.trim():'مستخدم MemoChat';
      final id=await ChatService().createChat(doctorId:doctorId.trim(),doctorName:doctorName.trim().isEmpty?'مستخدم':doctorName.trim(),patientName:name,doctorImage:doctorImage,patientImage:user.photoURL);
      if(!context.mounted)return;
      await Navigator.push(context,MaterialPageRoute(builder:(_)=>ChatRoomScreen(chatId:id,otherUserId:doctorId.trim(),otherUserName:doctorName.trim().isEmpty?'مستخدم':doctorName.trim(),groupImage:doctorImage,isGroup:false)));
    }catch(e){if(context.mounted)await ToastService.showError('فشل فتح المحادثة: $e');}
  }
  static Future<void> openCall(BuildContext context,{required String chatId,required String doctorName,required String doctorId,required bool isVideo}) async {
    final user=FirebaseAuth.instance.currentUser;
    if(user==null||chatId.trim().isEmpty||doctorId.trim().isEmpty||doctorId==user.uid){if(context.mounted)await ToastService.showError('بيانات المكالمة غير صالحة');return;}
    try{
      final call=await CallService().initiateCall(chatId:chatId,receiverId:doctorId,receiverName:doctorName,type:isVideo?CallType.video:CallType.audio);
      if(!context.mounted||call==null)return;
      await Navigator.push(context,MaterialPageRoute(builder:(_)=>CallScreen(chatId:chatId,doctorName:doctorName,doctorId:doctorId,callId:call.id,isVideo:isVideo,isOutgoing:true)));
    }catch(e){if(context.mounted)await ToastService.showError('فشل بدء المكالمة: $e');}
  }
}