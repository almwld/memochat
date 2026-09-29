import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../core/repositories/chat_repository.dart';
import '../core/repositories/firebase_chat_repository.dart';
import '../core/repositories/in_memory_chat_repository.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/home/presentation/home_screen.dart';

final GlobalKey<NavigatorState> memoNavigatorKey = GlobalKey<NavigatorState>();

class MemoChatApp extends StatefulWidget {
  const MemoChatApp({super.key});
  @override State<MemoChatApp> createState()=>_MemoChatAppState();
}
class _MemoChatAppState extends State<MemoChatApp>{
  final _fallbackRepository=InMemoryChatRepository();
  ThemeMode _themeMode=ThemeMode.system;
  ChatRepository get _repository=>Firebase.apps.isNotEmpty?FirebaseChatRepository():_fallbackRepository;

  @override void initState(){super.initState();unawaited(_initializeServices());}
  Future<void> _initializeServices() async {
    if(Firebase.apps.isEmpty)return;
    try{final user=FirebaseAuth.instance.currentUser;if(user!=null)await _syncUser(user);}catch(_){}
    if(mounted)setState((){});
  }
  Future<void> _syncUser(User user) async {
    final id='memo_'+user.uid.substring(0,8).toLowerCase();
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'displayName':user.displayName??'مستخدم MemoChat','username':id,'publicId':id,
      'photoUrl':user.photoURL??'','isOnline':true,'lastSeen':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp()
    },SetOptions(merge:true));
  }
  Future<void> _signOut() async {if(Firebase.apps.isNotEmpty)await FirebaseAuth.instance.signOut();}
  void _setThemeMode(ThemeMode mode){if(mounted)setState(()=>_themeMode=mode);}

  @override Widget build(BuildContext context)=>MaterialApp(
    navigatorKey:memoNavigatorKey,title:'MemoChat',debugShowCheckedModeBanner:false,
    theme:AppTheme.light(),darkTheme:AppTheme.dark(),themeMode:_themeMode,locale:const Locale('ar'),
    builder:(context,child)=>Directionality(textDirection:TextDirection.rtl,child:child??const SizedBox.shrink()),
    home:Firebase.apps.isEmpty?HomeScreen(repository:_repository,onThemeModeChanged:_setThemeMode,onSignOut:_signOut):
      StreamBuilder<User?>(
        stream:FirebaseAuth.instance.authStateChanges(),
        builder:(context,snapshot){
          if(snapshot.connectionState==ConnectionState.waiting)return const Scaffold(body:Center(child:CircularProgressIndicator()));
          final user=snapshot.data;
          if(user==null)return const AuthScreen();
          unawaited(_syncUser(user));
          return HomeScreen(repository:_repository,onThemeModeChanged:_setThemeMode,onSignOut:_signOut);
        },
      ),
  );
}