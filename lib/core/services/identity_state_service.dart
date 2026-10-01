import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IdentityStateService {
  final FirebaseFirestore db;
  final FirebaseAuth auth;

  IdentityStateService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  })  : db = firestore ?? FirebaseFirestore.instance,
        auth = firebaseAuth ?? FirebaseAuth.instance;

  Future<void> profile(Map<String, dynamic> patch) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');
    const allowed = {
      'displayName',
      'username',
      'photoUrl',
      'bio',
      'phone',
      'privacy',
    };
    final data = <String, dynamic>{};
    for (final entry in patch.entries) {
      if (allowed.contains(entry.key)) data[entry.key] = entry.value;
    }
    if (data.isEmpty) return;
    data['updatedAt'] = FieldValue.serverTimestamp();
    await db.collection('users').doc(uid).update(data);
  }

  Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'memochat_device_id_v1';
    final existing = prefs.getString(key);
    if (existing != null && existing.isNotEmpty) return existing;
    final seed =
        Platform.operatingSystem + '_' +
        DateTime.now().microsecondsSinceEpoch.toString();
    final id = 'device_' + seed.hashCode.abs().toRadixString(36);
    await prefs.setString(key, id);
    return id;
  }

  Future<void> device(String id, Map<String, dynamic> meta) async {
    final uid = auth.currentUser?.uid;
    if (uid == null || uid.isEmpty || id.isEmpty) return;
    await db.collection('users').doc(uid).collection('devices').doc(id).set({
      ...meta,
      'deviceId': id,
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> syncSession({bool online = true}) async {
    final uid = auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    final id = await deviceId();
    await device(id, {
      'platform': Platform.operatingSystem,
      'online': online,
      'app': 'MemoChat',
    });
    await db.collection('users').doc(uid).set({
      'isOnline': online,
      'lastSeen': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markOffline() async {
    final uid = auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    final id = await deviceId();
    await device(id, {'online': false});
    await db.collection('users').doc(uid).set({
      'isOnline': false,
      'lastSeen': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
