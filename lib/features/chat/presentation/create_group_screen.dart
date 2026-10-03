import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:memochat/features/chat/services/chat_service.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});
  @override State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _name = TextEditingController();
  final _service = ChatService();
  final _selected = <String>{};
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  bool _saving = false;

  @override void initState() { super.initState(); _loadUsers(); }
  @override void dispose() { _name.dispose(); super.dispose(); }

  Future<void> _loadUsers() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final snap = await FirebaseFirestore.instance.collection('users').limit(100).get();
      if (!mounted) return;
      setState(() {
        _users = snap.docs.where((d) => d.id != uid).map((d) {
          final data = d.data();
          return {'id': d.id, 'name': data['displayName']?.toString() ?? 'مستخدم', 'photoUrl': data['photoUrl']?.toString() ?? data['photoURL']?.toString()};
        }).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    if (_saving || _selected.isEmpty || _name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final details = <String, Map<String, dynamic>>{};
      for (final user in _users) {
        if (_selected.contains(user['id'])) details[user['id'].toString()] = user;
      }
      final id = await _service.createGroupChat(name: _name.text, memberIds: _selected.toList(), memberDetails: details);
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إنشاء المجموعة: ' + e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إنشاء مجموعة'), actions: [IconButton(onPressed: _saving ? null : _create, icon: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check))]),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم المجموعة', prefixIcon: Icon(Icons.groups_outlined)))),
      Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _users.isEmpty ? const Center(child: Text('لا يوجد مستخدمون متاحون')) : ListView.builder(
        itemCount: _users.length,
        itemBuilder: (_, i) {
          final user = _users[i];
          final id = user['id'].toString();
          return CheckboxListTile(
            value: _selected.contains(id),
            onChanged: (v) => setState(() => v == true ? _selected.add(id) : _selected.remove(id)),
            secondary: CircleAvatar(backgroundImage: (user['photoUrl']?.toString().isNotEmpty == true) ? NetworkImage(user['photoUrl'].toString()) : null, child: (user['photoUrl']?.toString().isNotEmpty == true) ? null : const Icon(Icons.person)),
            title: Text(user['name'].toString()),
          );
        },
      )),
    ]),
  );
}