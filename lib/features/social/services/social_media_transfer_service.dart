import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:workmanager/workmanager.dart';
import '../../../firebase_options.dart';
import '../../chat/services/nextcloud_service.dart';

const socialMediaTransferTask = 'memochat.social.media.transfer';

@pragma('vm:entry-point')
void socialMediaTransferCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      final service = SocialMediaTransferService.instance;
      await service.initialize(startWorker: false);
      await service.processPending();
      return true;
    } catch (_) { return false; }
  });
}

class SocialMediaTransferService {
  SocialMediaTransferService._();
  static final instance = SocialMediaTransferService._();
  Database? _db;
  bool _processing = false;
  bool _workerReady = false;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await openDatabase(
      p.join(await getDatabasesPath(), 'memochat_social_outbox.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE social_outbox (
            id TEXT PRIMARY KEY,
            uid TEXT NOT NULL,
            collection_name TEXT NOT NULL,
            local_path TEXT NOT NULL,
            type TEXT NOT NULL,
            caption TEXT NOT NULL,
            file_name TEXT NOT NULL,
            mime_type TEXT,
            status TEXT NOT NULL,
            progress REAL NOT NULL DEFAULT 0,
            remote_path TEXT,
            remote_url TEXT,
            error TEXT,
            attempts INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_social_outbox_status ON social_outbox(status, created_at)');
      },
    );
    return _db!;
  }

  Future<void> initialize({bool startWorker = true}) async {
    await _database;
    if (startWorker && !_workerReady) {
      try {
        await Workmanager().initialize(socialMediaTransferCallbackDispatcher, isInDebugMode: false);
        _workerReady = true;
        await Workmanager().registerPeriodicTask(
          'memochat-social-media-periodic',
          socialMediaTransferTask,
          frequency: const Duration(minutes: 15),
          constraints: Constraints(networkType: NetworkType.connected),
        );
      } catch (_) {}
    }
    unawaited(processPending());
  }

  Future<String> enqueue({
    required File sourceFile,
    required String collection,
    required String type,
    required String caption,
    String? fileName,
    String? mimeType,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('المستخدم غير مسجل الدخول');
    if (!await sourceFile.exists()) throw StateError('الملف المحلي غير موجود');
    if (collection != 'socialPosts' && collection != 'socialReels') {
      throw ArgumentError('مجموعة اجتماعية غير مدعومة');
    }
    final id = 'social_${DateTime.now().microsecondsSinceEpoch}_${sourceFile.uri.pathSegments.last.hashCode.abs()}';
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'memochat_social_media', user.uid));
    await dir.create(recursive: true);
    final raw = (fileName?.trim().isNotEmpty == true) ? fileName!.trim() : p.basename(sourceFile.path);
    final safe = raw.replaceAll(RegExp(r'[/\\\\]'), '_');
    final local = File(p.join(dir.path, '${id}_${safe}'));
    await sourceFile.copy(local.path);
    final now = DateTime.now().millisecondsSinceEpoch;
    final db = await _database;
    await db.insert('social_outbox', {
      'id': id,
      'uid': user.uid,
      'collection_name': collection,
      'local_path': local.path,
      'type': type,
      'caption': caption.trim(),
      'file_name': safe,
      'mime_type': mimeType,
      'status': 'queued',
      'created_at': now,
      'updated_at': now,
    });
    unawaited(processPending());
    return id;
  }

  Future<void> processPending() async {
    if (_processing) return;
    _processing = true;
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity is List && connectivity.every((x) => x == ConnectivityResult.none)) return;
      final db = await _database;
      final jobs = await db.query('social_outbox', where: "status != 'sent'", orderBy: 'created_at ASC', limit: 2);
      for (final job in jobs) {
        try { await _process(job); } catch (e) {
          await db.update('social_outbox', {
            'status': 'retry',
            'error': e.toString(),
            'attempts': (job['attempts'] as int? ?? 0) + 1,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          }, where: 'id = ?', whereArgs: [job['id']]);
        }
      }
    } finally { _processing = false; }
  }

  Future<void> _process(Map<String, dynamic> job) async {
    final db = await _database;
    final id = job['id'].toString();
    final file = File(job['local_path'].toString());
    if (!await file.exists()) throw StateError('النسخة المحلية للملف لم تعد موجودة');
    String? url;
    String? remotePath;
    try {
      final nc = NextcloudService();
      await nc.loadConfig();
      final upload = await nc.uploadFile(
        file: file,
        path: 'social/${job['collection_name']}/${job['uid']}',
        fileName: job['file_name']?.toString(),
        createShare: true,
      );
      if (upload.success && upload.path != null) {
        remotePath = upload.path;
        url = upload.url;
        if ((url ?? '').isEmpty) url = await nc.createPublicShare(remotePath!);
        if ((url ?? '').isNotEmpty && !await nc.verifyPublicUrl(url!)) url = null;
      }
    } catch (_) {}
    if ((url ?? '').isEmpty) {
      final path = 'social_media/${job['uid']}/${job['collection_name']}/${id}/${job['file_name']}';
      final ref = FirebaseStorage.instance.ref(path);
      final metadata = SettableMetadata(
        contentType: (job['mime_type']?.toString() ?? '').trim().isNotEmpty
            ? job['mime_type'].toString()
            : (job['type'] == 'video' ? 'video/mp4' : 'image/jpeg'),
        customMetadata: {'uid': job['uid'].toString(), 'outboxId': id},
      );
      final task = ref.putFile(file, metadata);
      final sub = task.snapshotEvents.listen((s) {
        if (s.totalBytes > 0) {
          unawaited(db.update('social_outbox', {
            'status': 'uploading',
            'progress': s.bytesTransferred / s.totalBytes,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          }, where: 'id = ?', whereArgs: [id]));
        }
      });
      try { await task; url = await ref.getDownloadURL(); remotePath = 'firebase://$path'; }
      finally { await sub.cancel(); }
    }
    if ((url ?? '').isEmpty) throw StateError('تعذر إنشاء رابط قابل للوصول للوسائط');
    final uid = job['uid'].toString();
    final collection = job['collection_name'].toString();
    final caption = job['caption'].toString();
    final data = collection == 'socialReels'
        ? <String, dynamic>{'authorId': uid, 'caption': caption, 'videoUrl': url, 'likesCount': 0, 'commentsCount': 0, 'sharesCount': 0, 'viewsCount': 0, 'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()}
        : <String, dynamic>{'authorId': uid, 'text': caption, 'mediaUrl': url, 'mediaType': job['type'].toString(), 'likesCount': 0, 'commentsCount': 0, 'sharesCount': 0, 'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()};
    await FirebaseFirestore.instance.collection(collection).doc(id).set(data);
    await db.update('social_outbox', {'status': 'sent', 'progress': 1.0, 'remote_path': remotePath, 'remote_url': url, 'error': null, 'updated_at': DateTime.now().millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [id]);
    try { await file.delete(); } catch (_) {}
  }
}
