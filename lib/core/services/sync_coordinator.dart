import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'offline_sync_queue.dart';

/// Owns durable local synchronization without UI dependencies.
class MemoChatSyncCoordinator {
  MemoChatSyncCoordinator({
    FirebaseAuth? auth,
    Connectivity? connectivity,
    OfflineSyncQueue? queue,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _connectivity = connectivity ?? Connectivity(),
        _queue = queue ?? OfflineSyncQueue();

  final FirebaseAuth _auth;
  final Connectivity _connectivity;
  final OfflineSyncQueue _queue;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _started = false;

  Future<void> initialize() async {
    if (_started) return;
    _started = true;
    _authSub = _auth.authStateChanges().listen((user) {
      unawaited(_flushForUser(user?.uid));
    });
    _connectivitySub = _connectivity.onConnectivityChanged.listen((_) {
      unawaited(_flushForUser(_auth.currentUser?.uid));
    });
    await _flushForUser(_auth.currentUser?.uid);
  }

  Future<void> _flushForUser(String? uid) async {
    if (uid == null || uid.isEmpty) return;
    try {
      await _queue.recoverStaleProcessing(uid: uid);
      await _queue.flush(uid: uid);
    } catch (_) {}
  }

  Future<int> pendingCount() =>
      _queue.pendingCount(uid: _auth.currentUser?.uid);

  Future<void> dispose() async {
    await _authSub?.cancel();
    await _connectivitySub?.cancel();
    _authSub = null;
    _connectivitySub = null;
    _started = false;
    await _queue.close();
  }
}
