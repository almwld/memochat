import 'package:flutter/material.dart';
import '../../../core/models/chat_folder.dart';
import '../../../core/services/chat_folder_service.dart';

class FoldersManagerScreen extends StatefulWidget {
  const FoldersManagerScreen({super.key});
  @override State<FoldersManagerScreen> createState() => _FoldersManagerScreenState();
}
class _FoldersManagerScreenState extends State<FoldersManagerScreen> {
  final _service = ChatFolderService();
  final _name = TextEditingController();
  @override void dispose() { _name.dispose(); super.dispose(); }
  Future<void> _create() async { final value = _name.text.trim(); if (value.isEmpty) return; await _service.createFolder(value); _name.clear(); if (mounted) setState(() {}); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('مجلدات المحادثات')),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        Expanded(child: TextField(controller: _name, decoration: const InputDecoration(hintText: 'اسم المجلد'))),
        const SizedBox(width: 8), FilledButton(onPressed: _create, child: const Icon(Icons.add)),
      ])),
      Expanded(child: FutureBuilder<List<ChatFolder>>(
        future: _service.getFolders(),
        builder: (_, snapshot) {
          final folders = snapshot.data ?? const <ChatFolder>[];
          if (folders.isEmpty) return const Center(child: Text('لا توجد مجلدات'));
          return ListView.separated(
            itemCount: folders.length, separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => ListTile(
              leading: const Icon(Icons.folder_outlined), title: Text(folders[i].name),
              subtitle: Text(folders[i].chatIds.length.toString() + ' محادثات'),
              trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async { await _service.removeFolder(folders[i].id); if (mounted) setState(() {}); }),
            ),
          );
        },
      )),
    ]),
  );
}