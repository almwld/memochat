import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
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
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeServices());
  }

  Future<void> _initializeServices() async {
    final firebaseReady = await FirebaseBootstrap.initialize().timeout(
      const Duration(seconds: 8),
      onTimeout: () => false,
    );
    if (!firebaseReady || !mounted) return;

    try {
      var user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        user = (await FirebaseAuth.instance.signInAnonymously().timeout(
          const Duration(seconds: 6),
        ))
            .user;
      }
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          {
            'displayName': user.displayName ?? 'مستخدم MemoChat',
            'username': user.displayName?.toLowerCase().replaceAll(' ', '_'),
            'photoUrl': user.photoURL ?? '',
            'isOnline': true,
            'lastSeen': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
    } catch (_) {
      // The UI remains usable; data screens rebuild when Firebase is ready.
    }

    if (mounted) setState(() {});
  }

  Future<void> _signOutAndReauthenticate() async {
    if (Firebase.apps.isEmpty) return;
    try {
      await FirebaseAuth.instance.signOut();
      await FirebaseAuth.instance.signInAnonymously().timeout(
        const Duration(seconds: 6),
      );
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  void _setThemeMode(ThemeMode mode) {
    if (mounted) setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
        repository: repository,
        onThemeModeChanged: _setThemeMode,
        onSignOut: _signOutAndReauthenticate,
      ),
    );
  }
}
