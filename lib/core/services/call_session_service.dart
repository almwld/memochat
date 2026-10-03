import 'package:cloud_firestore/cloud_firestore.dart';

class CallSessionService {
  final FirebaseFirestore? _firestore;

  CallSessionService({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore get db => _firestore ?? FirebaseFirestore.instance;

  static const allowedStatuses = {
    'calling',
    'ringing',
    'connected',
    'ended',
    'rejected',
    'cancelled',
    'missed',
    'busy',
    'failed',
  };

  static const terminalStatuses = {
    'ended',
    'rejected',
    'cancelled',
    'missed',
    'busy',
    'failed',
  };

  bool isTerminal(String status) => terminalStatuses.contains(status);

  Future<void> update(String id, Map<String, dynamic> patch) async {
    const allowed = {
      'status',
      'endedAt',
      'acceptedAt',
      'rejectedAt',
      'connectedAt',
      'muted',
      'cameraEnabled',
      'durationSeconds',
      'endedReason',
      'busyReason',
      'metadata',
    };
    final data = <String, dynamic>{};
    for (final entry in patch.entries) {
      if (allowed.contains(entry.key)) data[entry.key] = entry.value;
    }
    final status = data['status']?.toString();
    if (status != null && !allowedStatuses.contains(status)) {
      throw ArgumentError('Unsupported call status: ' + status);
    }
    if (data.isEmpty) return;
    data['updatedAt'] = FieldValue.serverTimestamp();
    await db.collection('calls').doc(id).update(data);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watch(String id) =>
      db.collection('calls').doc(id).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchForUser(
    String uid, {
    int limit = 20,
  }) =>
      db
          .collection('calls')
          .where('participants', arrayContains: uid)
          .limit(limit)
          .snapshots();
}
