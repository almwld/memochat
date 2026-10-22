import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Durable cache for media that has been opened or played at least once.
///
/// Files live in Application Support (not the OS temporary/cache directory),
/// so Android's routine cache cleanup will not remove offline media.
class LocalMediaCache {
  LocalMediaCache._();
  static final instance = LocalMediaCache._();

  Future<Directory> _directory() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, 'media_cache'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _key(String value) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// Signed download URLs may change their token/query string while pointing
  /// to the same media object. Ignore query and fragment when building the
  /// durable key so a refreshed URL can still find the offline copy.
  String _identity(Uri uri) {
    final normalized = uri.replace(query: '', fragment: '').toString();
    return normalized.replaceFirst(RegExp(r'[?#]$'), '');
  }

  String _extension(Uri uri) {
    final ext = p.extension(uri.path).toLowerCase();
    if (RegExp(r'^\.(mp4|m4v|mov|webm|mkv|mp3|m4a|aac|wav|ogg|opus|3gp|amr|jpg|jpeg|png|webp|gif|heic|heif|pdf|txt)$').hasMatch(ext)) {
      return ext;
    }
    return '.media';
  }

  Future<File?> existing(String url) async {
    final value = url.trim();
    if (value.isEmpty) return null;
    try {
      final uri = Uri.parse(value);
      final dir = await _directory();
      final ext = _extension(uri);

      // Prefer the stable key. Also look for the older exact-URL key so
      // media cached by previous app versions remains available offline.
      final candidates = <File>[
        File(p.join(dir.path, _key(_identity(uri)) + ext)),
        File(p.join(dir.path, _key(value) + ext)),
      ];
      for (final file in candidates) {
        if (await file.exists() && await file.length() > 0) return file;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<File?> getOrDownload(
    String url, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final value = url.trim();
    if (value.isEmpty) return null;
    final cached = await existing(value);
    if (cached != null) return cached;

    HttpClient? client;
    File? partial;
    try {
      final uri = Uri.parse(value);
      if (uri.scheme != 'https' && uri.scheme != 'http') return null;
      final dir = await _directory();
      final target = File(p.join(dir.path, _key(_identity(uri)) + _extension(uri)));
      partial = File(target.path + '.part');
      client = HttpClient()..connectionTimeout = timeout;
      final request = await client.getUrl(uri).timeout(timeout);
      final response = await request.close().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>();
        return null;
      }

      final sink = partial.openWrite();
      try {
        await for (final chunk in response.timeout(timeout)) {
          sink.add(chunk);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      if (!await partial.exists() || await partial.length() == 0) return null;
      if (await target.exists()) await target.delete();

      // Rename only after the entire response has been written. Readers never
      // see a half-downloaded file as a valid offline copy.
      return await partial.rename(target.path);
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
      if (partial != null && await partial.exists()) {
        try {
          await partial.delete();
        } catch (_) {}
      }
    }
  }
}
