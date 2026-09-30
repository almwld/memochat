import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../core/repositories/chat_repository.dart';
import '../core/repositories/firebase_chat_repository.dart';
import '../core/theme/app_theme.dart';
import '../core/services/firebase_bootstrap.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/home/presentation/home_screen.dart';
import 'memo_splash_screen.dart';

final GlobalKey<NavigatorState> memoNavigatorKey = GlobalKey<NavigatorState>();

class MemoChatApp extends StatefulWidget {
  const MemoChatApp({super.key});
  @override State<MemoChatApp> createState() => _MemoChatAppState();
}

class _MemoChatAppState extends State<MemoChatApp> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _firebaseReady = Firebase.apps.isNotEmpty;
  bool _showSplash = true;
  bool _initializationStarted = false;

  ChatRepository get _repository => FirebaseChatRepository();

  @override
  void initState() {
    super.initState();
    _startInitialization();

    // Splash lifetime is visual only. It never waits for Firebase or services.
    Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  void _markFirebaseReady() {
    if (mounted && !_firebaseReady) {
      setState(() => _firebaseReady = true);
    }
  }

  void _startInitialization() {
    if (_initializationStarted) return;
    _initializationStarted = true;
    unawaited(_initializeServices());
  }

  Future<void> _initializeServices() async {
    try {
      final ready = await FirebaseBootstrap.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () => false,
      );
      if (!mounted) return;
      setState(() => _firebaseReady = ready || Firebase.apps.isNotEmpty);
    } catch (error) {
      debugPrint('Firebase initialization failed: $error');
      if (mounted) setState(() => _firebaseReady = Firebase.apps.isNotEmpty);
    }

    if (!_firebaseReady || !mounted) return;

    // User sync is secondary and can never delay the first frame or login UI.
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) unawaited(_syncUser(user));
    } catch (error) {
      debugPrint('startup user sync failed: $error');
    }
  }

  Future<void> _syncUser(User user) async {
    final id = 'memo_' + user.uid.substring(0, 8).toLowerCase();
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'displayName': user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : 'مستخدم MemoChat',
      'username': id,
      'publicId': id,
      'photoUrl': user.photoURL ?? '',
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _signOut() async {
    if (Firebase.apps.isNotEmpty) await FirebaseAuth.instance.signOut();
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
      builder: (context, child) {
        ErrorWidget.builder = (details) => Directionality(
          textDirection: TextDirection.rtl,
          child: Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 52,
                        color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 14),
                    const Text('تعذر عرض هذه الشاشة',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text('حدث خطأ غير متوقع. عد إلى الشاشة السابقة وحاول مرة أخرى.',
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        );
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: _showSplash
          ? const MemoSplashScreen()
          : !_firebaseReady
              ? AuthScreen(onFirebaseReady: _markFirebaseReady)
              : StreamBuilder<User?>(
                  stream: FirebaseAuth.instance.authStateChanges(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const AuthScreen();
                    }
                    final user = snapshot.data;
                    if (user == null) return const AuthScreen();
                    unawaited(_syncUser(user));
                    return HomeScreen(
                      repository: _repository,
                      onThemeModeChanged: _setThemeMode,
                      onSignOut: _signOut,
                    );
                  },
                ),
    );
  }
}
