import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vibration/vibration.dart';

class ShakeMatch {
  const ShakeMatch({required this.id, required this.otherUserId});
  final String id;
  final String otherUserId;
}

class ShakeService {
  ShakeService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  StreamSubscription<AccelerometerEvent>? _accelerometer;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _presence;
  Timer? _expiryTimer;
  DateTime? _lastShake;
  bool _running = false;
  bool _publishing = false;
  bool _matchDeliveredForCurrentShake = false;

  String get _uid => _auth.currentUser?.uid ?? '';
  CollectionReference<Map<String, dynamic>> get _presenceCollection =>
      _firestore.collection('shakePresence');
  CollectionReference<Map<String, dynamic>> get _matchesCollection =>
      _firestore.collection('shakeMatches');

  Future<void> start({
    required void Function() onShake,
    required void Function(ShakeMatch match) onMatch,
    required void Function(Object error) onError,
  }) async {
    if (_running || _uid.isEmpty) return;
    _running = true;
    _presence = _presenceCollection.where('active', isEqualTo: true).limit(25).snapshots().listen((snapshot) async {
      try {
        for (final doc in snapshot.docs) {
          if (doc.id == _uid || _lastShake == null || _matchDeliveredForCurrentShake) continue;
          final data = doc.data();
          final expiresAt = data['expiresAt'];
          if (expiresAt is! Timestamp || expiresAt.toDate().isBefore(DateTime.now())) continue;
          final shakenAt = data['shakenAt'];
          if (shakenAt is! Timestamp || DateTime.now().difference(shakenAt.toDate()).abs() > const Duration(seconds: 4)) continue;
          if (DateTime.now().difference(_lastShake!).abs() > const Duration(seconds: 4)) continue;
          await _createMatch(doc.id);
          _matchDeliveredForCurrentShake = true;
          onMatch(ShakeMatch(id: _matchId(_uid, doc.id), otherUserId: doc.id));
          break;
        }
      } catch (error) {
        onError(error);
      }
    }, onError: onError);

    _accelerometer = accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen((event) async {
      final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      if (magnitude < 17.5) return;
      final now = DateTime.now();
      if (_lastShake != null && now.difference(_lastShake!) < const Duration(seconds: 3)) return;
      _lastShake = now;
      _matchDeliveredForCurrentShake = false;
      onShake();
      try {
        if (await Vibration.hasVibrator()) await Vibration.vibrate(duration: 80);
      } catch (_) {}
      await _publishPresence();
    }, onError: onError);
  }

  Future<void> _publishPresence() async {
    if (_publishing || _uid.isEmpty) return;
    _publishing = true;
    try {
      final now = DateTime.now();
      await _presenceCollection.doc(_uid).set({
        'uid': _uid,
        'active': true,
        'updatedAt': FieldValue.serverTimestamp(),
        'shakenAt': Timestamp.fromDate(now),
        'expiresAt': Timestamp.fromDate(now.add(const Duration(seconds: 8))),
      }, SetOptions(merge: true));
      _expiryTimer?.cancel();
      _expiryTimer = Timer(const Duration(seconds: 8), stopPresence);
    } finally {
      _publishing = false;
    }
  }

  Future<void> _createMatch(String otherUserId) async {
    if (_uid.isEmpty || otherUserId == _uid) return;
    final ids = [_uid, otherUserId]..sort();
    await _matchesCollection.doc(_matchId(_uid, otherUserId)).set({
      'participants': ids,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(seconds: 30))),
    }, SetOptions(merge: true));
  }

  Future<void> stopPresence() async {
    _expiryTimer?.cancel();
    if (_uid.isNotEmpty) {
      try {
        await _presenceCollection.doc(_uid).set({
          'active': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    _running = false;
    await _accelerometer?.cancel();
    await _presence?.cancel();
    _accelerometer = null;
    _presence = null;
    await stopPresence();
  }

  String _matchId(String first, String second) {
    final ids = [first, second]..sort();
    return '${ids[0]}_${ids[1]}';
  }
}