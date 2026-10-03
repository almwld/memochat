import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:workmanager/workmanager.dart';

import '../../firebase_options.dart';
import '../../features/chat/services/chat_service.dart';
import '../../features/chat/services/nextcloud_service.dart';

const mediaTransferTask = 'memochat.media.transfer';

enum MediaDestination { chat, socialPost, socialReel, status, voice }

class MediaUploadCancelled implements Exception {}

class MediaUploadResult {
  const MediaUploadResult({required this.success, this.url, this.remotePath, this.fileName, this.error});
  final bool success;
  final String? url;
  final String? remotePath;
  final String? fileName;
  final String? error;
}

@pragma('vm:entry-point')
void mediaTransferCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      final engine = MediaTransferEngine.instance;
      await engine.initialize(startWorker: false);
      await engine.processPending();
      return true;
    } catch (e) {
      debugPrint('media worker failed: ${e}');
      return false;
    }
  });
}

class MediaTransferEngine {
  MediaTransferEngine._();
  static final instance = MediaTransferEngine._();

  static const _maxBytes = 100 * 1024 * 1024;
  static const _maxAttempts = 8;
  Database? _db;
  StreamSubscription<dynamic>? _connectivity;
  final _cancelTokens = <String, CancelToken>{};
  final _cancelled = <String>{};
  bool _processing = false;
  bool _workerReady = false;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await openDatabase(
      p.join(await getDatabasesPath(), 'memochat_media_outbox.db'),
      version: 2,
      onCreate: (db, _) async { await _createSchema(db); await _migrateLegacyQueues(db); },
      onUpgrade: (db, old, _) async {
        if (old < 2) {
          await _addColumn(db, 'next_retry_at', 'INTEGER');
          await _addColumn(db, 'client_timestamp', 'INTEGER');
        }
      },
    );
    return _db!;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE media_outbox (
        id TEXT PRIMARY KEY,
        uid TEXT NOT NULL,
        destination TEXT NOT NULL,
        chat_id TEXT,
        collection_name TEXT,
        local_path TEXT NOT NULL,
        type TEXT NOT NULL,
        folder TEXT,
        caption TEXT,
        preview TEXT,
        file_name TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        mime_type TEXT,
        audio_duration TEXT,
        status TEXT NOT NULL,
        progress REAL NOT NULL DEFAULT 0,
        remote_path TEXT,
        remote_url TEXT,
        error TEXT,
        attempts INTEGER NOT NULL DEFAULT 0,
        next_retry_at INTEGER,
        client_timestamp INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_media_status ON media_outbox(status, next_retry_at, created_at)');
    await db.execute('CREATE INDEX idx_media_chat ON media_outbox(chat_id, created_at)');
  }

  Future<void> _migrateLegacyQueues(Database db) async {
    await db.execute('CREATE TABLE IF NOT EXISTS media_migrations (name TEXT PRIMARY KEY, completed_at INTEGER NOT NULL)');
    final done = await db.query('media_migrations', where: 'name = ?', whereArgs: ['legacy_outboxes_v1'], limit: 1);
    if (done.isNotEmpty) return;

    Future<void> migrateChat() async {
      final legacyPath = p.join(await getDatabasesPath(), 'memochat_chat_outbox.db');
      if (!await File(legacyPath).exists()) return;
      Database? legacy;
      try {
        legacy = await openDatabase(legacyPath, readOnly: true);
        final rows = await legacy.query('media_outbox', where: "status != 'sent'");
        for (final row in rows) {
          final local = row['local_path']?.toString() ?? '';
          if (local.isEmpty || !await File(local).exists()) continue;
          final id = row['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          final exists = await db.query('media_outbox', where: 'id = ?', whereArgs: [id], limit: 1);
          if (exists.isNotEmpty) continue;
          final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
          if (uid.isEmpty) continue;
          await db.insert('media_outbox', {
            'id': id, 'uid': uid, 'destination': row['type'] == 'audio' ? 'voice' : 'chat',
            'chat_id': row['chat_id'], 'local_path': local, 'type': row['type'] ?? 'file',
            'folder': row['folder'] ?? 'files', 'caption': row['preview'] ?? '',
            'preview': row['preview'] ?? '', 'file_name': row['file_name'] ?? p.basename(local),
            'file_size': int.tryParse(row['file_size']?.toString() ?? '') ?? await File(local).length(),
            'mime_type': row['mime_type'], 'audio_duration': row['audio_duration'],
            'status': 'queued', 'progress': row['progress'] ?? 0.0, 'attempts': row['attempts'] ?? 0,
            'client_timestamp': row['client_timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
            'created_at': row['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          });
        }
      } finally {
        await legacy?.close();
      }
    }

    Future<void> migrateSocial() async {
      final legacyPath = p.join(await getDatabasesPath(), 'memochat_social_outbox.db');
      if (!await File(legacyPath).exists()) return;
      Database? legacy;
      try {
        legacy = await openDatabase(legacyPath, readOnly: true);
        final rows = await legacy.query('social_outbox', where: "status != 'sent'");
        for (final row in rows) {
          final local = row['local_path']?.toString() ?? '';
          final id = row['id']?.toString() ?? '';
          if (local.isEmpty || id.isEmpty || !await File(local).exists()) continue;
          final exists = await db.query('media_outbox', where: 'id = ?', whereArgs: [id], limit: 1);
          if (exists.isNotEmpty) continue;
          final collection = row['collection_name']?.toString() ?? 'socialPosts';
          await db.insert('media_outbox', {
            'id': id, 'uid': row['uid'], 'destination': collection == 'socialReels' ? 'socialReel' : 'socialPost',
            'collection_name': collection, 'local_path': local, 'type': row['type'] ?? 'image',
            'folder': collection, 'caption': row['caption'] ?? '', 'preview': row['caption'] ?? '',
            'file_name': row['file_name'] ?? p.basename(local),
            'file_size': await File(local).length(), 'mime_type': row['mime_type'],
            'status': 'queued', 'progress': row['progress'] ?? 0.0, 'attempts': row['attempts'] ?? 0,
            'client_timestamp': row['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
            'created_at': row['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          });
        }
      } finally {
        await legacy?.close();
      }
    }

    await migrateChat();
    await migrateSocial();
    await db.insert('media_migrations', {'name': 'legacy_outboxes_v1', 'completed_at': DateTime.now().millisecondsSinceEpoch});
  }

  Future<void> _addColumn(Database db, String name, String definition) async {
    final rows = await db.rawQuery('PRAGMA table_info(media_outbox)');
    if (!rows.any((r) => r['name'] == name)) {
      await db.execute('ALTER TABLE media_outbox ADD COLUMN ${name} ${definition}');
    }
  }

  Future<void> initialize({bool startWorker = true}) async {
    await _database;
    await _connectivity?.cancel();
    _connectivity = Connectivity().onConnectivityChanged.listen((_) {
      unawaited(processPending());
      unawaited(_scheduleWorker());
    });
    if (startWorker) await _initWorker();
    unawaited(processPending());
  }

  Future<void> _initWorker() async {
    if (_workerReady) return;
    try {
      await Workmanager().initialize(mediaTransferCallbackDispatcher, isInDebugMode: false);
      _workerReady = true;
      await Workmanager().registerPeriodicTask(
        'memochat-media-periodic',
        mediaTransferTask,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
      );
      await _scheduleWorker();
    } catch (e) {
      debugPrint('media worker init: ${e}');
    }
  }

  Future<void> _scheduleWorker() async {
    if (!_workerReady) return;
    try {
      await Workmanager().registerOneOffTask(
        'memochat-media-${DateTime.now().microsecondsSinceEpoch}',
        mediaTransferTask,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (e) {
      debugPrint('media worker schedule: ${e}');
    }
  }

  Future<String> enqueue({
    required File sourceFile,
    required MediaDestination destination,
    required String type,
    required String folder,
    required String caption,
    String? chatId,
    String? collectionName,
    String? preview,
    String? fileName,
    String? mimeType,
    String? audioDuration,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('المستخدم غير مسجل الدخول');
    if (!await sourceFile.exists()) throw StateError('الملف المحلي غير موجود');

    final size = await sourceFile.length();
    final safeName = _safeName(fileName?.trim().isNotEmpty == true ? fileName!.trim() : p.basename(sourceFile.path));
    _validate(type, safeName, mimeType, size);

    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _idempotencyId(user.uid, destination, chatId ?? collectionName ?? 'media', sourceFile, safeName, now);
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'memochat_media', user.uid));
    await dir.create(recursive: true);
    final local = File(p.join(dir.path, '${id}_${safeName}'));
    if (local.path != sourceFile.path) await sourceFile.copy(local.path);

    final db = await _database;
    final existing = await db.query('media_outbox', where: 'id = ?', whereArgs: [id], limit: 1);
    if (existing.isEmpty) {
      await db.insert('media_outbox', {
        'id': id,
        'uid': user.uid,
        'destination': destination.name,
        'chat_id': chatId,
        'collection_name': collectionName,
        'local_path': local.path,
        'type': type,
        'folder': folder,
        'caption': caption.trim(),
        'preview': preview ?? caption.trim(),
        'file_name': safeName,
        'file_size': size,
        'mime_type': _normalizedMime(type, mimeType),
        'audio_duration': audioDuration,
        'status': 'queued',
        'progress': 0.0,
        'attempts': 0,
        'client_timestamp': now,
        'created_at': now,
        'updated_at': now,
      });
    }
    unawaited(processPending());
    unawaited(_scheduleWorker());
    return id;
  }

  String _idempotencyId(String uid, MediaDestination destination, String scope, File file, String name, int timestamp) {
    final stat = file.statSync();
    final seed = '${uid}|${destination.name}|${scope}|${name}|${stat.size}|${stat.modified.millisecondsSinceEpoch}|${timestamp}';
    return 'media_${seed.hashCode.abs()}_${timestamp}';
  }

  String _safeName(String name) {
    final value = name.replaceAll(RegExp(r'[/\\]'), '_').replaceAll('..', '_').trim();
    if (value.isEmpty) throw ArgumentError('اسم الملف غير صالح');
    return value;
  }

  String _ext(String name) => p.extension(name).toLowerCase().replaceFirst('.', '');

  String _normalizedMime(String type, String? mime) {
    final value = mime?.trim().toLowerCase() ?? '';
    if (value.isNotEmpty) return value;
    if (type == 'image') return 'image/jpeg';
    if (type == 'video') return 'video/mp4';
    if (type == 'audio') return 'audio/mp4';
    return 'application/octet-stream';
  }

  void _validate(String type, String name, String? mime, int size) {
    if (size <= 0) throw StateError('الملف فارغ');
    if (size > _maxBytes) throw StateError('حجم الوسائط يتجاوز 100MB');
    const images = {'jpg','jpeg','png','webp','gif','heic','heif'};
    const videos = {'mp4','mov','m4v','webm','3gp','mkv'};
    const audios = {'m4a','aac','mp3','wav','ogg','opus','amr'};
    const files = {'pdf','txt','doc','docx','xls','xlsx','ppt','pptx','zip','rar','7z','csv','json'};
    final ext = _ext(name);
    final valid = type == 'image' ? images.contains(ext)
        : type == 'video' ? videos.contains(ext)
        : type == 'audio' ? audios.contains(ext)
        : type == 'file' ? files.contains(ext) : false;
    if (!valid) throw StateError('امتداد الملف لا يطابق نوع الوسائط: .${ext}');
    final value = mime?.trim().toLowerCase() ?? '';
    if (value.isEmpty) return;
    final mimeValid = type == 'image' ? value.startsWith('image/')
        : type == 'video' ? value.startsWith('video/')
        : type == 'audio' ? value.startsWith('audio/')
        : type == 'file' ? (value == 'application/pdf' || value == 'text/plain' || value == 'text/csv' ||
            value == 'application/json' || value.contains('officedocument') || value == 'application/zip' ||
            value == 'application/x-rar-compressed' || value == 'application/octet-stream') : false;
    if (!mimeValid) throw StateError('MIME type لا يطابق نوع الوسائط');
  }

  Future<Map<String, dynamic>?> getById(String id) async {
    final db = await _database;
    final rows = await db.query('media_outbox', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> pendingForChat(String chatId) async {
    final db = await _database;
    return db.query('media_outbox', where: 'chat_id = ? AND status != ?', whereArgs: [chatId, 'sent'], orderBy: 'created_at ASC');
  }

  Future<void> processPending() async {
    if (_processing) return;
    _processing = true;
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (_offline(connectivity)) return;
      final db = await _database;
      final now = DateTime.now().millisecondsSinceEpoch;
      final jobs = await db.query(
        'media_outbox',
        where: "status != 'sent' AND (next_retry_at IS NULL OR next_retry_at <= ?)",
        whereArgs: [now],
        orderBy: 'created_at ASC',
        limit: 4,
      );
      for (final job in jobs) {
        try {
          await _process(job);
        } catch (e, st) {
          if (e is MediaUploadCancelled) continue;
          final attempts = (job['attempts'] as int? ?? 0) + 1;
          final delay = _backoff(attempts);
          await db.update('media_outbox', {
            'status': attempts >= _maxAttempts ? 'failed' : 'retry',
            'error': e.toString(),
            'attempts': attempts,
            'next_retry_at': DateTime.now().add(delay).millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          }, where: 'id = ?', whereArgs: [job['id']]);
          debugPrint('media ${job['id']} failed attempt=${attempts}, retry=${delay.inSeconds}s: ${e}');
          debugPrint('${st}');
        }
      }
    } finally {
      _processing = false;
    }
  }

  bool _offline(dynamic value) {
    if (value is List<ConnectivityResult>) return value.isEmpty || value.every((x) => x == ConnectivityResult.none);
    return value == ConnectivityResult.none;
  }

  Duration _backoff(int attempt) {
    final seconds = (2 << (attempt - 1)).clamp(2, 900).toInt();
    return Duration(milliseconds: seconds * 1000 + (DateTime.now().microsecond % 1000));
  }

  Future<void> _process(Map<String, dynamic> job) async {
    final id = job['id'].toString();
    final file = File(job['local_path'].toString());
    if (_cancelled.contains(id)) throw MediaUploadCancelled();

    final db = await _database;
    String? readyUrl;
    final existingUrl = job['remote_url']?.toString();
    final existingStatus = job['status']?.toString();
    if (existingUrl != null && existingUrl.isNotEmpty &&
        existingStatus != 'sent') {
      // The upload already completed. If Firestore publication failed, retry only
      // the publication instead of uploading the same media again.
      readyUrl = existingUrl;
    } else {
      if (!await file.exists()) {
        throw StateError('النسخة المحلية للملف لم تعد موجودة');
      }
      final result = await _upload(
        id: id,
        file: file,
        type: job['type'].toString(),
        remoteDirectory: _remoteDirectory(job),
        fileName: job['file_name'].toString(),
        mimeType: job['mime_type']?.toString(),
      );
      if (!result.success || result.url == null || result.url!.isEmpty) {
        throw StateError(result.error ?? 'تعذر تجهيز رابط قابل للوصول للوسائط');
      }

      readyUrl = result.url;
      await db.update('media_outbox', {
        'status': 'link_ready',
        'progress': 1.0,
        'remote_path': result.remotePath,
        'remote_url': result.url,
        'error': null,
        'next_retry_at': null,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      }, where: 'id = ?', whereArgs: [id]);
    }

    final destination = MediaDestination.values.firstWhere((v) => v.name == job['destination'].toString());
    if (destination == MediaDestination.chat || destination == MediaDestination.voice) {
      await _publishChat(job, readyUrl!);
    } else if (destination == MediaDestination.socialPost || destination == MediaDestination.socialReel) {
      await _publishSocial(job, readyUrl!);
    }

    await db.update('media_outbox', {
      'status': 'sent',
      'progress': 1.0,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, where: 'id = ?', whereArgs: [id]);
    _cancelled.remove(id);
    _cancelTokens.remove(id);
    try { await file.delete(); } catch (_) {}
  }

  String _remoteDirectory(Map<String, dynamic> job) {
    final uid = job['uid'].toString();
    final type = job['type'].toString();
    final destination = job['destination'].toString();
    if (destination == 'chat' || destination == 'voice') return 'chat/${uid}/${job['chat_id']}/${type}/${job['id']}';
    if (destination == 'status') return 'status/${uid}/${type}/${job['id']}';
    return 'social/${uid}/${job['collection_name']}/${type}/${job['id']}';
  }

  Future<MediaUploadResult> _upload({
    required String id,
    required File file,
    required String type,
    required String remoteDirectory,
    required String fileName,
    required String? mimeType,
  }) async {
    final nc = NextcloudService();
    await nc.loadConfig();
    final token = _cancelTokens.putIfAbsent(id, CancelToken.new);
    try {
      final result = await nc.uploadFile(
        file: file,
        path: remoteDirectory,
        fileName: fileName,
        mimeType: mimeType,
        cancelToken: token,
        createShare: true,
        onProgress: (sent, total) {
          if (total > 0) {
            unawaited(_database.then((db) => db.update('media_outbox', {
              'status': 'uploading',
              'progress': (sent / total).clamp(0.0, 1.0),
              'updated_at': DateTime.now().millisecondsSinceEpoch,
            }, where: 'id = ?', whereArgs: [id])));
          }
        },
      );
      if (_cancelled.contains(id)) throw MediaUploadCancelled();
      if (!result.success || result.path == null) return MediaUploadResult(success: false, error: result.error);
      var url = result.url;
      if (url == null || url.isEmpty) url = await nc.createPublicShare(result.path!);
      if (url == null || url.isEmpty) return MediaUploadResult(success: false, remotePath: result.path, error: result.error ?? 'تعذر إنشاء رابط Nextcloud');
      if (!await nc.verifyPublicUrl(url)) return MediaUploadResult(success: false, remotePath: result.path, error: 'رابط Nextcloud غير قابل للوصول');
      return MediaUploadResult(success: true, url: url, remotePath: result.path, fileName: result.fileName);
    } catch (e) {
      if (_cancelled.contains(id)) throw MediaUploadCancelled();
      return MediaUploadResult(success: false, error: e.toString());
    }
  }

  Future<MediaUploadResult> uploadNow({
    required File file,
    required MediaDestination destination,
    required String type,
    required String folder,
    String? chatId,
    String? collectionName,
    String? fileName,
    String? mimeType,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('المستخدم غير مسجل الدخول');
    if (!await file.exists()) throw StateError('الملف المحلي غير موجود');
    final name = _safeName(fileName?.trim().isNotEmpty == true ? fileName!.trim() : p.basename(file.path));
    _validate(type, name, mimeType, await file.length());
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _idempotencyId(user.uid, destination, chatId ?? collectionName ?? 'media', file, name, now);
    return _upload(
      id: id,
      file: file,
      type: type,
      remoteDirectory: _remoteDirectory({
        'uid': user.uid,
        'destination': destination.name,
        'chat_id': chatId,
        'collection_name': collectionName,
        'id': id,
      }),
      fileName: name,
      mimeType: mimeType,
    );
  }

  Future<void> _publishChat(Map<String, dynamic> job, String url) async {
    final type = job['type'].toString();
    await ChatService().sendMessage(
      chatId: job['chat_id'].toString(),
      messageId: job['id'].toString(),
      text: job['preview']?.toString() ?? '',
      imageUrl: type == 'image' ? url : null,
      videoUrl: type == 'video' ? url : null,
      audioUrl: type == 'audio' ? url : null,
      fileUrl: type == 'file' ? url : null,
      fileName: job['file_name']?.toString(),
      fileSize: job['file_size']?.toString(),
      fileMimeType: job['mime_type']?.toString(),
      audioDuration: job['audio_duration']?.toString(),
      idempotencyKey: 'media_${job['id']}',
    );
  }

  Future<void> _publishSocial(Map<String, dynamic> job, String url) async {
    final uid = job['uid'].toString();
    final collection = job['collection_name'].toString();
    final caption = job['caption']?.toString() ?? '';
    final data = collection == 'socialReels'
        ? <String, dynamic>{
            'authorId': uid,
            'authorName': FirebaseAuth.instance.currentUser?.displayName ?? 'مستخدم Memo',
            'authorPhoto': FirebaseAuth.instance.currentUser?.photoURL ?? '',
            'caption': caption,
            'videoUrl': url,
            'thumbnailUrl': '',
            'likesCount': 0,
            'commentsCount': 0,
            'sharesCount': 0,
            'viewsCount': 0,
            'isPublished': true,
            'commentsEnabled': true,
            'isPinned': false,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }
        : <String, dynamic>{
            'authorId': uid, 'text': caption, 'mediaUrl': url, 'mediaType': job['type'].toString(),
            'likesCount': 0, 'commentsCount': 0, 'sharesCount': 0,
            'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp(),
          };
    await FirebaseFirestore.instance.collection(collection).doc(job['id'].toString()).set(data);
  }

  Future<void> cancel(String id) async {
    _cancelled.add(id);
    _cancelTokens[id]?.cancel('Cancelled by user');
    final db = await _database;
    final job = await getById(id);
    if (job != null) {
      final local = job['local_path']?.toString();
      await db.delete('media_outbox', where: 'id = ?', whereArgs: [id]);
      if (local != null) { try { await File(local).delete(); } catch (_) {} }
    }
    _cancelTokens.remove(id);
  }

  Future<void> retry(String id) async {
    _cancelled.remove(id);
    _cancelTokens.remove(id);
    final db = await _database;
    if (await getById(id) == null) return;
    await db.update('media_outbox', {
      'status': 'queued',
      'error': null,
      'next_retry_at': null,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, where: 'id = ?', whereArgs: [id]);
    unawaited(processPending());
    unawaited(_scheduleWorker());
  }

  Future<void> dispose() async {
    await _connectivity?.cancel();
    _connectivity = null;
    await _db?.close();
    _db = null;
  }
}
