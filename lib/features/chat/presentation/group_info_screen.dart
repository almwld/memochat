import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:memochat/features/chat/services/chat_service.dart';
import 'package:share_plus/share_plus.dart';

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

  Future<void> _addMember(List<String> existing) async {
    final snap = await FirebaseFirestore.instance.collection('users').limit(100).get();
    final candidates = snap.docs.where((doc) => doc.id != FirebaseAuth.instance.currentUser?.uid && !existing.contains(doc.id) && doc.data()['hideFromContacts'] != true).toList();
    if (!mounted) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        itemCount: candidates.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, index) {
          final doc = candidates[index];
          final d = doc.data();
          final name = d['displayName']?.toString().trim().isNotEmpty == true ? d['displayName'].toString().trim() : 'مستخدم';
          final photo = d['photoUrl']?.toString().trim() ?? '';
          return ListTile(
            leading: CircleAvatar(backgroundImage: photo.isEmpty ? null : NetworkImage(photo), child: photo.isEmpty ? const Icon(Icons.person_outline) : null),
            title: Text(name),
            subtitle: Text(d['publicId']?.toString() ?? ''),
            onTap: () => Navigator.pop(context, doc.id),
          );
        },
      ),
    );
    if (selected == null) return;
    final data = candidates.firstWhere((doc) => doc.id == selected).data();
    final name = data['displayName']?.toString() ?? 'مستخدم';
    try {
      await _service.addMemberToGroup(widget.chatId, selected, memberName: name, memberPhoto: data['photoUrl']?.toString());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة العضو وإرسال إشعار له.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إضافة العضو: $e')));
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
            if (canManage)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FilledButton.icon(
                  onPressed: () => _addMember(participants),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('إضافة عضو'),
                ),
              ),
            if (canManage)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FilledButton.icon(
                  onPressed: () async {
                    try {
                      final link = await _service.generateInviteLink(widget.chatId);
                      await Share.share(link, subject: 'دعوة إلى مجموعة MemoChat');
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  },
                  icon: const Icon(Icons.link),
                  label: const Text('إنشاء رابط دعوة'),
                ),
              ),
            const SizedBox(height: 14),
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