import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Durable local-first queue for Firestore synchronization.
class OfflineSyncQueue {
  final FirebaseFirestore db;
  Database? _localDb;
  Future<Database>? _opening;

  OfflineSyncQueue({FirebaseFirestore? firestore})
      : db = firestore ?? FirebaseFirestore.instance;

  Future<Database> _database() {
    final existing = _localDb;
    if (existing != null) return Future.value(existing);
    final opening = _opening;
    if (opening != null) return opening;

    final future = () async {
      final directory = await getApplicationDocumentsDirectory();
      final database = await openDatabase(
        p.join(directory.path, 'memochat_sync_queue.db'),
        version: 1,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE sync_queue (
              uid TEXT NOT NULL,
              id TEXT NOT NULL,
              payload TEXT NOT NULL,
              state TEXT NOT NULL,
              attempts INTEGER NOT NULL DEFAULT 0,
              next_attempt_at INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              PRIMARY KEY (uid, id)
            )
          ''');
          await database.execute(
            'CREATE INDEX idx_sync_queue_pending '
            'ON sync_queue(state, next_attempt_at, created_at)',
          );
        },
      );
      _localDb = database;
      return database;
    }();

    _opening = future;
    return future.whenComplete(() => _opening = null);
  }

  Future<void> enqueue(
    String uid,
    String id,
    Map<String, dynamic> payload,
  ) async {
    if (uid.trim().isEmpty || id.trim().isEmpty) {
      throw ArgumentError('uid and id are required');
    }

    final database = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.insert(
      'sync_queue',
      {
        'uid': uid,
        'id': id,
        'payload': jsonEncode(payload),
        'state': 'pending',
        'attempts': 0,
        'next_attempt_at': now,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    try {
      await _writeRemote(uid, id, payload);
      await complete(uid, id);
    } catch (_) {
      // Keep the local entry; flush() will retry with backoff.
    }
  }

  Future<void> flush({String? uid, int limit = 50}) async {
    final database = await _database();
    final now = DateTime.now().millisecondsSinceEpoch;
    final where = uid == null
        ? 'state = ? AND next_attempt_at <= ?'
        : 'state = ? AND next_attempt_at <= ? AND uid = ?';
    final args = uid == null
        ? <Object>[ 'pending', now ]
        : <Object>[ 'pending', now, uid ];

    final rows = await database.query(
      'sync_queue',
      where: where,
      whereArgs: args,
      orderBy: 'created_at ASC',
      limit: limit,
    );

    for (final row in rows) {
      final rowUid = row['uid'] as String;
      final id = row['id'] as String;
      final attempts = (row['attempts'] as int?) ?? 0;
      final payload =
          jsonDecode(row['payload'] as String) as Map<String, dynamic>;

      try {
        await database.update(
          'sync_queue',
          {
            'state': 'processing',
            'attempts': attempts + 1,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'uid = ? AND id = ?',
          whereArgs: [rowUid, id],
        );

        await _writeRemote(rowUid, id, payload);
        await complete(rowUid, id);
      } catch (_) {
        final nextAttempt = DateTime.now()
            .add(_backoff(attempts + 1))
            .millisecondsSinceEpoch;
        await database.update(
          'sync_queue',
          {
            'state': 'pending',
            'next_attempt_at': nextAttempt,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'uid = ? AND id = ?',
          whereArgs: [rowUid, id],
        );
      }
    }
  }

  Future<void> complete(String uid, String id) async {
    final database = await _database();
    await database.delete(
      'sync_queue',
      where: 'uid = ? AND id = ?',
      whereArgs: [uid, id],
    );

    try {
      await db
          .collection('users')
          .doc(uid)
          .collection('syncQueue')
          .doc(id)
          .set({
        'state': 'done',
        'completedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Firestore SDK remains offline-capable; local delivery state is kept.
    }
  }

  Future<int> pendingCount({String? uid}) async {
    final database = await _database();
    final where = uid == null
        ? 'state IN (?, ?)'
        : 'state IN (?, ?) AND uid = ?';
    final args = uid == null
        ? <Object>['pending', 'processing']
        : <Object>['pending', 'processing', uid];
    final result = await database.rawQuery(
      'SELECT COUNT(*) AS count FROM sync_queue WHERE ' + where,
      args,
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<void> close() async {
    final database = _localDb;
    _localDb = null;
    if (database != null) {
      await database.close();
    }
  }

  Future<void> _writeRemote(
    String uid,
    String id,
    Map<String, dynamic> payload,
  ) {
    return db
        .collection('users')
        .doc(uid)
        .collection('syncQueue')
        .doc(id)
        .set({
      'payload': payload,
      'state': 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Duration _backoff(int attempt) {
    final exponent = attempt.clamp(0, 5) as int;
    final seconds = 1 << exponent;
    return Duration(seconds: seconds > 32 ? 32 : seconds);
  }
}
