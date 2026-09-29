final GlobalKey<NavigatorState> memoNavigatorKey = GlobalKey<NavigatorState>();
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../core/repositories/in_memory_chat_repository.dart';
import '../core/theme/app_theme.dart';
import '../features/home/presentation/home_screen.dart';

class MemoChatApp extends StatefulWidget {
  const MemoChatApp({super.key});
  @override State<MemoChatApp> createState()=>_MemoChatAppState();
}
class _MemoChatAppState extends State<MemoChatApp> {
  late final repository=InMemoryChatRepository();
  bool _ready=Firebase.apps.isEmpty || FirebaseAuth.instance.currentUser!=null;
  @override void initState(){super.initState();_ensureAuth();}
  Future<void> _ensureAuth() async {
    if(Firebase.apps.isEmpty)return;
    if(FirebaseAuth.instance.currentUser==null){try{await FirebaseAuth.instance.signInAnonymously();}catch(_){}}
    if(mounted)setState(()=>_ready=FirebaseAuth.instance.currentUser!=null);
  }
  @override Widget build(BuildContext context)=>MaterialApp(
    navigatorKey:memoNavigatorKey,title:'MemoChat',debugShowCheckedModeBanner:false,theme:AppTheme.light(),
    home:_ready?HomeScreen(repository:repository):const Scaffold(
      body:Center(child:CircularProgressIndicator(color:Color(0xFF0A8F83))),
    ),
  );
}
