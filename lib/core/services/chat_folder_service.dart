import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_folder.dart';

class ChatFolderService {
  static const _key = 'memo_chat_folders';
  Future<List<ChatFolder>> getFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    return raw.map((e) => ChatFolder.fromJson(Map<String, dynamic>.from(jsonDecode(e) as Map))).where((f) => f.id.isNotEmpty).toList();
  }
  Future<void> saveFolders(List<ChatFolder> folders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, folders.map((f) => jsonEncode(f.toJson())).toList());
  }
  Future<ChatFolder> createFolder(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('اسم المجلد فارغ');
    final folders = await getFolders();
    final folder = ChatFolder(id: 'folder_' + DateTime.now().microsecondsSinceEpoch.toString(), name: clean);
    await saveFolders([...folders, folder]);
    return folder;
  }
  Future<void> removeFolder(String id) async {
    final folders = await getFolders();
    await saveFolders(folders.where((f) => f.id != id).toList());
  }
  Future<void> setChatInFolder(String folderId, String chatId, bool included) async {
    final folders = await getFolders();
    final updated = folders.map((f) {
      if (f.id != folderId) return f;
      final ids = {...f.chatIds};
      if (included) ids.add(chatId); else ids.remove(chatId);
      return ChatFolder(id: f.id, name: f.name, chatIds: ids.toList());
    }).toList();
    await saveFolders(updated);
  }
}