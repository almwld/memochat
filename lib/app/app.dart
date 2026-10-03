import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../core/repositories/in_memory_chat_repository.dart';
import '../core/theme/app_theme.dart';
import '../features/home/presentation/main_shell.dart';

final GlobalKey<NavigatorState> memoNavigatorKey = GlobalKey<NavigatorState>();

class MemoChatApp extends StatefulWidget {
  const MemoChatApp({super.key});

  @override
  State<MemoChatApp> createState() => _MemoChatAppState();
}

class _MemoChatAppState extends State<MemoChatApp> {
  late final repository = InMemoryChatRepository();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _ensureAuth();
  }

  Future<void> _ensureAuth() async {
    if (Firebase.apps.isEmpty) {
      if (mounted) setState(() => _ready = true);
      return;
    }

    if (FirebaseAuth.instance.currentUser == null) {
      try {
        await FirebaseAuth.instance.signInAnonymously().timeout(const Duration(seconds: 5));
      } catch (_) {
        // Auth configuration must not blank the application.
      }
    }

    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: memoNavigatorKey,
      title: 'MemoChat',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      theme: AppTheme.light(),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: !_ready
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF0A8F83)),
              ),
            )
          : const MainShell(),
    );
  }
}
