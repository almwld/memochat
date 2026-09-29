import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../core/repositories/in_memory_chat_repository.dart';
import '../core/services/firebase_bootstrap.dart';
import '../core/theme/app_theme.dart';
import '../features/home/presentation/home_screen.dart';

final GlobalKey<NavigatorState> memoNavigatorKey = GlobalKey<NavigatorState>();

class MemoChatApp extends StatefulWidget {
  const MemoChatApp({super.key});

  @override
  State<MemoChatApp> createState() => _MemoChatAppState();
}

class _MemoChatAppState extends State<MemoChatApp> {
  late final repository = InMemoryChatRepository();
  bool _ready = false;
  bool _firebaseFailed = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final initialized = await FirebaseBootstrap.initialize();
    if (!initialized) {
      if (mounted) {
        setState(() {
          _firebaseFailed = true;
          _ready = true;
        });
      }
      return;
    }

    if (FirebaseAuth.instance.currentUser == null) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
      } catch (_) {}
    }

    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: memoNavigatorKey,
      title: 'MemoChat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: !_ready
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF0A8F83)),
              ),
            )
          : HomeScreen(repository: repository, firebaseFailed: _firebaseFailed),
    );
  }
}
