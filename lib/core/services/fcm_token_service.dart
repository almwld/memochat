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
  String? _lastSyncedUid;
  String? _lastSyncedToken;
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
        _lastSyncedUid = null;
        _lastSyncedToken = null;
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
      final token = await _messaging.getToken().timeout(const Duration(seconds: 4));
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
    final previousUid = _lastSyncedUid;
    final previousToken = _lastSyncedToken;
    final future = _writeToken(user.uid, normalized);
    _syncInFlight = future;
    try {
      await future;
      if (_auth.currentUser?.uid == user.uid) {
        _lastSyncedKey = syncKey;
        _lastSyncedUid = user.uid;
        _lastSyncedToken = normalized;
        // FCM may rotate a device token. Keep the new token before removing
        // the old one so the account never has an avoidable notification gap.
        if (previousUid == user.uid &&
            previousToken != null &&
            previousToken.isNotEmpty &&
            previousToken != normalized) {
          await _removeTokenForUser(user.uid, previousToken);
        }
      }
    } finally {
      if (identical(_syncInFlight, future)) _syncInFlight = null;
    }
  }

  Future<void> _removeTokenForUser(String uid, String token) async {
    if (_auth.currentUser?.uid != uid || token.trim().isEmpty) return;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('private')
          .doc('tokens')
          .set({
        'tokens': FieldValue.arrayRemove([token.trim()]),
        'updatedAt': FieldValue.serverTimestamp(),
        'platform': 'android',
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 4));
    } catch (error, stack) {
      debugPrint('FCM stale token cleanup failed: $error');
      debugPrintStack(stackTrace: stack);
    }
  }

  /// Removes this device's push token while the account is still authenticated.
  /// Call before signing out; Firestore rules may reject cleanup afterwards.
  Future<void> removeCurrentToken() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final tokens = <String>{};
    try {
      final token = await _messaging.getToken().timeout(const Duration(seconds: 4));
      if (token != null && token.trim().isNotEmpty) tokens.add(token.trim());
    } catch (error) {
      debugPrint('FCM token lookup during sign-out failed: $error');
    }
    if (_lastSyncedUid == user.uid &&
        _lastSyncedToken?.trim().isNotEmpty == true) {
      tokens.add(_lastSyncedToken!.trim());
    }
    if (tokens.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('private')
            .doc('tokens')
            .set({
          'tokens': FieldValue.arrayRemove(tokens.toList()),
          'updatedAt': FieldValue.serverTimestamp(),
          'platform': 'android',
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 4));
      } catch (error, stack) {
        debugPrint('FCM token cleanup during sign-out failed: $error');
        debugPrintStack(stackTrace: stack);
      }
    }
    _lastSyncedKey = null;
    _lastSyncedUid = null;
    _lastSyncedToken = null;
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
    _lastSyncedUid = null;
    _lastSyncedToken = null;
    _started = false;
  }
}