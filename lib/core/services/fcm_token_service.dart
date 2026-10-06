import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Owns the FCM token lifecycle for the currently signed-in MemoChat user.
///
/// Push notifications remain an enhancement: Firestore chat listeners are the
/// authoritative message transport. This service only keeps recipient tokens
/// synchronized and never becomes a prerequisite for sending messages.
class FcmTokenService {
  FcmTokenService._();
  static final FcmTokenService instance = FcmTokenService._();
  StreamSubscription<String>? _refreshSubscription;
  StreamSubscription<User?>? _authSubscription;
  Future<void>? _syncInFlight;
  String? _lastSyncedKey;
  bool _started = false;
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _refreshSubscription = _messaging.onTokenRefresh.listen(
      (token) => unawaited(syncToken(token)),
      onError: (Object error, StackTrace stack) {
        debugPrint('FCM token refresh failed: $error');
        debugPrintStack(stackTrace: stack);
      },
    );
    _authSubscription = _auth.authStateChanges().listen((user) {
      if (user == null) {
        _lastSyncedKey = null;
      } else {
        unawaited(syncCurrentToken());
      }
    });
    if (_auth.currentUser != null) unawaited(syncCurrentToken());
  }

  Future<String?> syncCurrentToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      final token = await _messaging.getToken();
      if (token == null || token.trim().isEmpty) return null;
      await syncToken(token);
      return token;
    } catch (error, stack) {
      debugPrint('FCM getToken failed: $error');
      debugPrintStack(stackTrace: stack);
      return null;
    }
  }

  Future<void> syncToken(String token) async {
    final user = _auth.currentUser;
    final normalized = token.trim();
    if (user == null || user.uid.isEmpty || normalized.isEmpty) return;
    final syncKey = '${user.uid}::$normalized';
    if (_lastSyncedKey == syncKey) return;
    final previous = _syncInFlight;
    if (previous != null) {
      await previous;
      if (_lastSyncedKey == syncKey) return;
    }
    final future = _writeToken(user.uid, normalized);
    _syncInFlight = future;
    try {
      await future;
      if (_auth.currentUser?.uid == user.uid) _lastSyncedKey = syncKey;
    } finally {
      if (identical(_syncInFlight, future)) _syncInFlight = null;
    }
  }

  Future<void> _writeToken(String uid, String token) async {
    if (_auth.currentUser?.uid != uid) return;
    final ref = _firestore.collection('users').doc(uid).collection('private').doc('tokens');
    await ref.set({
      'tokens': FieldValue.arrayUnion([token]),
      'updatedAt': FieldValue.serverTimestamp(),
      'platform': 'android',
    }, SetOptions(merge: true));
  }

  Future<void> dispose() async {
    await _refreshSubscription?.cancel();
    await _authSubscription?.cancel();
    _refreshSubscription = null;
    _authSubscription = null;
    _syncInFlight = null;
    _lastSyncedKey = null;
    _started = false;
  }
}