import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:memochat/features/chat/services/chat_service.dart';

class GroupInfoScreen extends StatefulWidget {
  const GroupInfoScreen({super.key, required this.chatId});
  final String chatId;
  @override State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final _service = ChatService();

  Future<void> _changeRole(String memberId, bool admin) async {
    try {
      if (admin) {
        await _service.promoteToAdmin(widget.chatId, memberId);
      } else {
        await _service.demoteFromAdmin(widget.chatId, memberId);
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _remove(String memberId) async {
    try {
      await _service.removeMember(widget.chatId, memberId);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('معلومات المجموعة')),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).snapshots(),
      builder: (_, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final details = Map<String, dynamic>.from(data['participantDetails'] as Map? ?? const {});
        final roles = Map<String, dynamic>.from(data['memberRoles'] as Map? ?? const {});
        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final canManage = roles[uid] == 'owner' || roles[uid] == 'admin';
        final participants = List<String>.from(data['participants'] as List? ?? const []);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(child: CircleAvatar(radius: 42, child: Text((data['groupName']?.toString().trim().isNotEmpty == true ? data['groupName'].toString().trim() : 'م').characters.first))),
            const SizedBox(height: 10),
            Center(child: Text(data['groupName']?.toString() ?? 'مجموعة', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
            const SizedBox(height: 22),
            Text('الأعضاء (' + participants.length.toString() + ')', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final id in participants)
              ListTile(
                leading: CircleAvatar(child: const Icon(Icons.person_outline)),
                title: Text(details[id] is Map ? (details[id]['name']?.toString() ?? 'مستخدم') : 'مستخدم'),
                subtitle: Text(roles[id]?.toString() == 'owner' ? 'المالك' : roles[id]?.toString() == 'admin' ? 'مدير' : 'عضو'),
                trailing: canManage && id != uid && roles[id] != 'owner'
                    ? PopupMenuButton<String>(
                        onSelected: (v) => v == 'remove' ? _remove(id) : _changeRole(id, v == 'admin'),
                        itemBuilder: (_) => [
                          PopupMenuItem(value: roles[id] == 'admin' ? 'member' : 'admin', child: Text(roles[id] == 'admin' ? 'إلغاء المدير' : 'ترقية لمدير')),
                          const PopupMenuItem(value: 'remove', child: Text('إزالة من المجموعة')),
                        ],
                      )
                    : null,
              ),
          ],
        );
      },
    ),
  );
}