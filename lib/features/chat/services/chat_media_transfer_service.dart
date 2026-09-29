import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:workmanager/workmanager.dart';

import '../../firebase_options.dart';
import 'chat_service.dart';
import 'nextcloud_service.dart';

const String chatMediaTransferTask = 'sehatak.chat.media.transfer';

@pragma('vm:entry-point')
void chatMediaTransferCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      final service = ChatMediaTransferService.instance;
      await service.initialize(startBackgroundWorker: false);
      await service.processPending();
      return true;
    } catch (e) {
      debugPrint('media worker failed: $e');
      return false;
    }
  });
}

class MediaUploadCancelled implements Exception {}

class ChatMediaTransferService {
  ChatMediaTransferService._();
  static final ChatMediaTransferService instance = ChatMediaTransferService._();

  Database? _db;
  StreamSubscription<dynamic>? _connectivitySub;
  bool _processing = false;
  bool _workerInitialized = false;
  final Map<String, UploadTask> _activeFirebaseTasks = {};
  final Map<String, CancelToken> _activeCancelTokens = {};
  final Set<String> _cancelledIds = {};

  CancelToken _cancelToken(String id) {
    return _activeCancelTokens.putIfAbsent(id, CancelToken.new);
  }

  bool _isCancelled(String id) => _cancelledIds.contains(id);

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final root = await getDatabasesPath();
    _db = await openDatabase(
      p.join(root, 'sehatak_chat_outbox.db'),
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE media_outbox (
            id TEXT PRIMARY KEY,
            chat_id TEXT NOT NULL,
            local_path TEXT NOT NULL,
            type TEXT NOT NULL,
            folder TEXT NOT NULL,
            preview TEXT NOT NULL,
            file_name TEXT,
            file_size TEXT,
            mime_type TEXT,
            audio_duration TEXT,
            status TEXT NOT NULL,
            progress REAL NOT NULL DEFAULT 0,
            remote_path TEXT,
            remote_url TEXT,
            error TEXT,
            attempts INTEGER NOT NULL DEFAULT 0,
            client_timestamp INTEGER,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_media_outbox_chat ON media_outbox(chat_id, created_at)');
        await db.execute('CREATE INDEX idx_media_outbox_status ON media_outbox(status, created_at)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          final columns = await db.rawQuery('PRAGMA table_info(media_outbox)');
          final hasClientTimestamp = columns.any((column) => column['name'] == 'client_timestamp');
          if (!hasClientTimestamp) {
            await db.execute('ALTER TABLE media_outbox ADD COLUMN client_timestamp INTEGER');
            debugPrint('media_outbox migration: added client_timestamp');
          }
        }
      },
    );
    return _db!;
  }

  Future<void> initialize({bool startBackgroundWorker = true}) async {
    await _database;
    await _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((_) {
      unawaited(processPending());
      unawaited(_scheduleOneOffWorker());
    });
    if (startBackgroundWorker) await _initializeBackgroundWorker();
    unawaited(processPending());
  }

  Future<void> _initializeBackgroundWorker() async {
    if (_workerInitialized) return;
    try {
      await Workmanager().initialize(chatMediaTransferCallbackDispatcher, isInDebugMode: false);
      _workerInitialized = true;
      await Workmanager().registerPeriodicTask(
        'sehatak-chat-media-periodic',
        chatMediaTransferTask,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
      );
      await _scheduleOneOffWorker();
    } catch (e) {
      debugPrint('media workmanager init: $e');
    }
  }

  Future<void> _scheduleOneOffWorker() async {
    if (!_workerInitialized) return;
    try {
      await Workmanager().registerOneOffTask(
        'sehatak-chat-media-${DateTime.now().microsecondsSinceEpoch}',
        chatMediaTransferTask,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (e) {
      debugPrint('media workmanager schedule: $e');
    }
  }

  Future<String> enqueue({
    required String chatId,
    required File sourceFile,
    required String type,
    required String folder,
    required String preview,
    String? fileName,
    String? fileSize,
    String? mimeType,
    String? audioDuration,
  }) async {
    if (!await sourceFile.exists()) throw StateError('الملف المحلي غير موجود');
    final id = '${chatId}_${DateTime.now().microsecondsSinceEpoch}_${sourceFile.uri.pathSegments.last.hashCode.abs()}';
    final dir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(dir.path, 'sehatak_chat_media', chatId));
    await mediaDir.create(recursive: true);
    final rawName = fileName?.trim().isNotEmpty == true ? fileName!.trim() : p.basename(sourceFile.path);
    final safeName = rawName.replaceAll(RegExp(r'[/\\]'), '_');
    final local = File(p.join(mediaDir.path, '${id}_$safeName'));
    await sourceFile.copy(local.path);
    final now = DateTime.now().millisecondsSinceEpoch;
    final db = await _database;
    await db.insert('media_outbox', {
      'id': id,
      'chat_id': chatId,
      'local_path': local.path,
      'type': type,
      'folder': folder,
      'preview': preview,
      'file_name': safeName,
      'file_size': fileSize,
      'mime_type': mimeType,
      'audio_duration': audioDuration,
      'status': 'queued',
      'progress': 0.0,
      'attempts': 0,
      'client_timestamp': now,
      'created_at': now,
      'updated_at': now,
    });
    unawaited(processPending());
    unawaited(_scheduleOneOffWorker());
    return id;
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
      if (_isOffline(connectivity)) return;
      final db = await _database;
      final jobs = await db.query('media_outbox', where: 'status != ?', whereArgs: ['sent'], orderBy: 'created_at ASC', limit: 3);
      for (final job in jobs) {
        try {
          await _process(job);
        } catch (e, st) {
          if (e is MediaUploadCancelled) continue;
          debugPrint('❌ media job ${job['id']} failed: $e');
          debugPrint('$st');
          await db.update('media_outbox', {
            'status': 'retry',
            'error': e.toString(),
            'attempts': (job['attempts'] as int? ?? 0) + 1,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          }, where: 'id = ?', whereArgs: [job['id']]);
        }
      }
    } finally {
      _processing = false;
    }
  }

  bool _isOffline(dynamic result) {
    if (result is List<ConnectivityResult>) {
      return result.isEmpty || (result.length == 1 && result.first == ConnectivityResult.none);
    }
    return result == ConnectivityResult.none;
  }

  Future<void> _process(Map<String, dynamic> job) async {
    final db = await _database;
    final id = job['id'].toString();
    final localPath = job['local_path']?.toString() ?? '';
    final file = File(localPath);
    if (!await file.exists()) throw StateError('النسخة المحلية للملف لم تعد موجودة');

    var remotePath = job['remote_path']?.toString();
    var url = job['remote_url']?.toString();
    final type = job['type']?.toString() ?? 'file';
    if (_isCancelled(id)) throw MediaUploadCancelled();

    if (url == null || url.isEmpty) {
      final provider = remotePath?.startsWith('firebase://') == true ? 'firebase' : 'nextcloud';
      if (provider == 'firebase') {
        url = await _firebaseUrl(job, file, id);
        remotePath = 'firebase://chat_media/${job['chat_id']}/$type/$id/${job['file_name']}';
      } else {
        final nextcloud = NextcloudService();
        await nextcloud.loadConfig();
        NextcloudUploadResult upload;
        try {
          upload = await nextcloud.uploadFile(
            file: file,
            path: 'chats/${job['chat_id']}/${job['folder']}',
            fileName: job['file_name']?.toString(),
            cancelToken: _cancelToken(id),
            onProgress: (sent, total) {
              if (total > 0) {
                unawaited(db.update('media_outbox', {
                  'status': 'uploading',
                  'progress': (sent / total).clamp(0.0, 1.0),
                  'updated_at': DateTime.now().millisecondsSinceEpoch,
                }, where: 'id = ?', whereArgs: [id]));
              }
            },
            createShare: true,
          );
        } catch (e) {
          if (_isCancelled(id)) throw MediaUploadCancelled();
          upload = NextcloudUploadResult(success: false, error: e.toString());
        }
        if (_isCancelled(id)) throw MediaUploadCancelled();
        if (upload.success && upload.path != null) {
          remotePath = upload.path;
          url = upload.url;
          if (url == null || url.isEmpty) {
            url = await _retryShare(nextcloud, remotePath!);
          }
          if (url != null && url.isNotEmpty) {
            final reachable = await nextcloud.verifyPublicUrl(url);
            if (!reachable) url = null;
          }
        }
        // Nextcloud is optional. If it is not configured or share creation fails,
        // transparently fall back to Firebase Storage so the message still gets delivered.
        if (url == null || url.isEmpty) {
          debugPrint('⚠️ Nextcloud media delivery unavailable; using Firebase Storage fallback. error=${upload.error}');
          url = await _firebaseUrl(job, file, id);
          remotePath = 'firebase://chat_media/${job['chat_id']}/$type/$id/${job['file_name']}';
        }
      }
    }

    if (_isCancelled(id)) throw MediaUploadCancelled();
    if (url == null || url.isEmpty) throw StateError('تعذر إنشاء رابط قابل للوصول للوسائط');
    await db.update('media_outbox', {
      'status': 'link_ready',
      'remote_path': remotePath,
      'remote_url': url,
      'progress': 1.0,
      'error': null,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, where: 'id = ?', whereArgs: [id]);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('المستخدم غير مسجل الدخول');
    await ChatService().sendMessage(
      chatId: job['chat_id'].toString(),
      messageId: id,
      text: job['preview'].toString(),
      imageUrl: type == 'image' ? url : null,
      videoUrl: type == 'video' ? url : null,
      audioUrl: type == 'audio' ? url : null,
      fileUrl: type == 'file' ? url : null,
      fileName: job['file_name']?.toString(),
      fileSize: job['file_size']?.toString(),
      fileMimeType: job['mime_type']?.toString(),
      audioDuration: job['audio_duration']?.toString(),
      idempotencyKey: 'media_$id',
    );
    await db.update('media_outbox', {
      'status': 'sent',
      'remote_path': remotePath,
      'remote_url': url,
      'progress': 1.0,
      'error': null,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, where: 'id = ?', whereArgs: [id]);
    try { await file.delete(); } catch (_) {}
  }

  Future<String> _firebaseUrl(Map<String, dynamic> job, File file, String id) async {
    final chatId = job['chat_id'].toString();
    final type = job['type']?.toString() ?? 'file';
    final name = job['file_name']?.toString() ?? p.basename(file.path);
    final path = 'chat_media/$chatId/$type/$id/$name';
    final ref = FirebaseStorage.instance.ref().child(path);
    final metadata = SettableMetadata(
      contentType: job['mime_type']?.toString()?.trim().isNotEmpty == true
          ? job['mime_type'].toString()
          : _defaultMime(type),
      customMetadata: {'chatId': chatId, 'senderId': FirebaseAuth.instance.currentUser?.uid ?? '', 'outboxId': id},
    );
    final task = ref.putFile(file, metadata);
    _activeFirebaseTasks[id] = task;
    final sub = task.snapshotEvents.listen((snapshot) {
      final total = snapshot.totalBytes;
      if (total <= 0) return;
      unawaited(_database.then((db) => db.update('media_outbox', {
        'status': 'uploading',
        'progress': (snapshot.bytesTransferred / total).clamp(0.0, 1.0),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      }, where: 'id = ?', whereArgs: [id])));
    });
    try {
      await task;
      if (_isCancelled(id)) throw MediaUploadCancelled();
      return await ref.getDownloadURL();
    } finally {
      await sub.cancel();
      _activeFirebaseTasks.remove(id);
    }
  }

  String _defaultMime(String type) {
    switch (type) {
      case 'image': return 'image/jpeg';
      case 'video': return 'video/mp4';
      case 'audio': return 'audio/mpeg';
      default: return 'application/octet-stream';
    }
  }

  Future<String?> _retryShare(NextcloudService service, String remotePath) async {
    for (var i = 0; i < 3; i++) {
      final url = await service.createPublicShare(remotePath);
      if (url != null && url.isNotEmpty) return url;
      await Future<void>.delayed(Duration(seconds: 2 * (i + 1)));
    }
    return null;
  }

  Future<void> cancel(String id) async {
    _cancelledIds.add(id);
    final task = _activeFirebaseTasks[id];
    if (task != null) {
      await task.cancel();
    }
    final db = await _database;
    final job = await getById(id);
    if (job != null) {
      final localPath = job['local_path']?.toString();
      await db.delete('media_outbox', where: 'id = ?', whereArgs: [id]);
      if (localPath != null && localPath.isNotEmpty) {
        try { await File(localPath).delete(); } catch (_) {}
      }
    }
    _activeFirebaseTasks.remove(id);
    _activeCancelTokens.remove(id);
  }

  Future<void> retry(String id) async {
    final db = await _database;
    final job = await getById(id);
    if (job == null) return;
    await db.update('media_outbox', {
      'status': 'queued',
      'error': null,
      'remote_path': job['remote_path']?.toString().startsWith('firebase://') == true ? job['remote_path'] : null,
      'remote_url': job['remote_path']?.toString().startsWith('firebase://') == true ? job['remote_url'] : null,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, where: 'id = ?', whereArgs: [id]);
    await processPending();
    unawaited(_scheduleOneOffWorker());
  }

  Future<void> dispose() async {
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    await _db?.close();
    _db = null;
  }
}