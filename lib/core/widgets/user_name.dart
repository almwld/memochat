import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserCacheService {
  UserCacheService._();
  static final UserCacheService instance = UserCacheService._();

  final Map<String, String> _cache = <String, String>{};
  final Map<String, Future<String>> _pending = <String, Future<String>>{};

  Future<String> getName(String uid) {
    final id = uid.trim();
    if (id.isEmpty) return Future.value('مستخدم');
    final cached = _cache[id];
    if (cached != null && cached.isNotEmpty) return Future.value(cached);
    return _pending[id] ??= _load(id).whenComplete(() => _pending.remove(id));
  }

  Future<String> _load(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = snap.data() ?? const <String, dynamic>{};
      final resolved = _first(data, const ['displayName', 'username', 'publicId']);
      final name = resolved.isEmpty ? 'مستخدم' : resolved;
      _cache[uid] = name;
      return name;
    } catch (_) {
      return 'مستخدم';
    }
  }

  String _first(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String resolve(Map<String, dynamic> data) {
    for (final key in const ['userName', 'displayName', 'authorName', 'senderName']) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    for (final key in const ['userId', 'authorId', 'senderId']) {
      final uid = data[key]?.toString().trim() ?? '';
      final cached = _cache[uid];
      if (cached != null && cached.isNotEmpty) return cached;
    }
    return 'مستخدم';
  }

  void put(String uid, String name) {
    final id = uid.trim();
    final value = name.trim();
    if (id.isNotEmpty && value.isNotEmpty) _cache[id] = value;
  }

  void clear() {
    _cache.clear();
    _pending.clear();
  }
}

class UserName extends StatelessWidget {
  const UserName({super.key, required this.userId, this.directName, this.style});
  final String userId;
  final String? directName;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final direct = directName?.trim() ?? '';
    if (direct.isNotEmpty) {
      UserCacheService.instance.put(userId, direct);
      return Text(direct, style: style);
    }
    return FutureBuilder<String>(
      future: UserCacheService.instance.getName(userId),
      builder: (_, snapshot) => Text(
        snapshot.data?.trim().isNotEmpty == true ? snapshot.data!.trim() : 'مستخدم',
        style: style,
      ),
    );
  }
}
