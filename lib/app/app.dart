import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../core/repositories/chat_repository.dart';
import '../core/repositories/firebase_chat_repository.dart';
import '../core/repositories/in_memory_chat_repository.dart';
import '../core/theme/app_theme.dart';
import '../features/home/presentation/home_screen.dart';

final GlobalKey<NavigatorState> memoNavigatorKey = GlobalKey<NavigatorState>();

class MemoChatApp extends StatefulWidget {
  const MemoChatApp({super.key});

  @override
  State<MemoChatApp> createState() => _MemoChatAppState();
}

class _MemoChatAppState extends State<MemoChatApp> {
  final _fallbackRepository = InMemoryChatRepository();
  ThemeMode _themeMode = ThemeMode.system;

  ChatRepository get _repository =>
      Firebase.apps.isNotEmpty ? FirebaseChatRepository() : _fallbackRepository;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeServices());
  }

  Future<void> _initializeServices() async {
    if (Firebase.apps.isEmpty) return;

    try {
      var user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        user = (await FirebaseAuth.instance.signInAnonymously()).user;
      }
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          {
            'displayName': user.displayName ?? 'مستخدم MemoChat',
            'username': user.displayName?.toLowerCase().replaceAll(' ', '_') ??
                'user_${user.uid.substring(0, 6)}',
            'photoUrl': user.photoURL ?? '',
            'isOnline': true,
            'lastSeen': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    } catch (_) {
      // Firebase errors remain local to the affected feature.
    }

    if (mounted) setState(() {});
  }

  Future<void> _signOutAndReauthenticate() async {
    if (Firebase.apps.isEmpty) return;
    try {
      await FirebaseAuth.instance.signOut();
      await FirebaseAuth.instance.signInAnonymously();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  void _setThemeMode(ThemeMode mode) {
    if (mounted) setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        navigatorKey: memoNavigatorKey,
        title: 'MemoChat',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: _themeMode,
        locale: const Locale('ar'),
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
        home: HomeScreen(
          repository: _repository,
          onThemeModeChanged: _setThemeMode,
          onSignOut: _signOutAndReauthenticate,
        ),
      );
}
