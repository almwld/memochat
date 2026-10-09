import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/repositories/chat_repository.dart';
import '../core/repositories/firebase_chat_repository.dart';
import '../core/theme/app_theme.dart';
import '../core/services/firebase_bootstrap.dart';
import '../core/services/identity_state_service.dart';
import '../core/services/sync_coordinator.dart';
import '../core/media/media_transfer_engine.dart';
import '../features/chat/services/chat_media_transfer_service.dart';
import '../core/notifications/push_notification_service.dart';
import '../features/chat/services/notification_service.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/home/presentation/home_screen.dart';
import 'memo_splash_screen.dart';

final GlobalKey<NavigatorState> memoNavigatorKey = GlobalKey<NavigatorState>();

class MemoChatApp extends StatefulWidget {
  const MemoChatApp({super.key});
  @override State<MemoChatApp> createState() => _MemoChatAppState();
}

class _MemoChatAppState extends State<MemoChatApp>
    with WidgetsBindingObserver {
  static const _splashLastShownKey = 'memo_splash_last_shown_at_ms';
  static const _splashInterval = Duration(hours: 12);

  static const _themeKey = 'settings.theme';
  static const _pendingCameraChatKey = 'memochat.pending_camera_chat_id';

  ThemeMode _themeMode = ThemeMode.system;
  bool _firebaseReady = Firebase.apps.isNotEmpty;
  bool _showSplash = true;
  bool _initializationStarted = false;
  String? _lastSyncedUid;
  String? _pushInitializedUid;
  PushNotificationService? _pushNotifications;
  final NotificationService _localNotifications = NotificationService();
  final IdentityStateService _identity = IdentityStateService();
  final MemoChatSyncCoordinator _syncCoordinator = MemoChatSyncCoordinator();
  bool _lifecycleStarted = false;
  Stream<User?>? _authStream;
  ChatRepository? _repo;

  ChatRepository get _repository => _repo ??= FirebaseChatRepository();
  Stream<User?> get _authenticationStream => _authStream ??= FirebaseAuth.instance.authStateChanges();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startInitialization();
    unawaited(_loadPersistedTheme());
    unawaited(_initializeSplash());
    unawaited(_recoverLostCameraMedia());
  }

  Future<void> _initializeSplash() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final lastShownMs = preferences.getInt(_splashLastShownKey);
      final now = DateTime.now();
      final shouldShow = lastShownMs == null ||
          now.difference(DateTime.fromMillisecondsSinceEpoch(lastShownMs)) >= _splashInterval;

      if (!shouldShow) {
        if (mounted) setState(() => _showSplash = false);
        return;
      }

      await preferences.setInt(_splashLastShownKey, now.millisecondsSinceEpoch);
      if (!mounted) return;

      Timer(const Duration(milliseconds: 1100), () {
        if (mounted) setState(() => _showSplash = false);
      });
    } catch (error) {
      debugPrint('Splash schedule check failed: $error');
      if (mounted) {
        Timer(const Duration(milliseconds: 1100), () {
          if (mounted) setState(() => _showSplash = false);
        });
      }
    }
  }

  Future<void> _recoverLostCameraMedia() async {
    // Only query ImagePicker when a camera request was recorded. This avoids
    // consuming a lost result belonging to another picker flow.
    try {
      final preferences = await SharedPreferences.getInstance();
      final chatId = preferences.getString(_pendingCameraChatKey);
      if (chatId == null || chatId.trim().isEmpty) return;

      final response = await ImagePicker().retrieveLostData();
      if (response.isEmpty) {
        await preferences.remove(_pendingCameraChatKey);
        return;
      }
      if (response.exception != null) {
        debugPrint('MemoChat: lost camera result recovery failed: ${response.exception}');
        await preferences.remove(_pendingCameraChatKey);
        return;
      }

      final files = response.files ?? const <XFile>[];
      if (files.isEmpty) {
        await preferences.remove(_pendingCameraChatKey);
        return;
      }

      for (final picked in files) {
        final file = File(picked.path);
        if (!await file.exists() || await file.length() == 0) continue;
        final lowerPath = picked.path.toLowerCase();
        final mime = lowerPath.endsWith('.png')
            ? 'image/png'
            : lowerPath.endsWith('.webp')
                ? 'image/webp'
                : 'image/jpeg';
        await ChatMediaTransferService.instance.enqueue(
          chatId: chatId,
          sourceFile: file,
          type: 'image',
          folder: 'images',
          preview: '📷 صورة',
          fileName: picked.name,
          mimeType: mime,
        );
      }
      await preferences.remove(_pendingCameraChatKey);
      debugPrint('MemoChat: recovered lost camera result for chat $chatId');
    } catch (error, stackTrace) {
      debugPrint('MemoChat: camera result recovery failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _loadPersistedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_themeKey);
      final mode = switch (value) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      if (mounted) setState(() => _themeMode = mode);
    } catch (error) {
      debugPrint('MemoChat: failed to restore theme: $error');
    }
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

    if (!_lifecycleStarted) {
      _lifecycleStarted = true;
      unawaited(_syncCoordinator.initialize());
      unawaited(MediaTransferEngine.instance.initialize());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (Firebase.apps.isEmpty) {
      _initializationStarted = false;
      _firebaseReady = false;
      _startInitialization();
    } else if (mounted && !_firebaseReady) {
      setState(() => _firebaseReady = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_syncCoordinator.dispose());
    unawaited(MediaTransferEngine.instance.dispose());
    super.dispose();
  }

  Future<void> _initializePushNotifications(User user) async {
    if (_pushInitializedUid == user.uid) return;
    _pushInitializedUid = user.uid;
    final service = PushNotificationService(
      localNotifications: _localNotifications,
    );
    _pushNotifications = service;
    try {
      await service.initialize().timeout(const Duration(seconds: 15));
      debugPrint('MemoChat: FCM initialized for uid=${user.uid}');
    } catch (error, stackTrace) {
      if (_pushInitializedUid == user.uid) _pushInitializedUid = null;
      debugPrint('MemoChat: FCM initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
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
    }, SetOptions(merge: true));
    await _identity.syncSession();
  }

  Future<void> _signOut() async {
    if (Firebase.apps.isEmpty) return;
    try {
      await _identity.markOffline();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
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
                  stream: _authenticationStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const _AuthLoadingScreen();
                    }
                    final user = snapshot.data;
                    if (user == null) return const AuthScreen();
                    if (_lastSyncedUid != user.uid) {
                      _lastSyncedUid = user.uid;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted || _lastSyncedUid != user.uid) return;
                        unawaited(_syncUser(user));
                        unawaited(_initializePushNotifications(user));
                      });
                    }
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

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_rounded, size: 54, color: scheme.primary),
            const SizedBox(height: 18),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: scheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
