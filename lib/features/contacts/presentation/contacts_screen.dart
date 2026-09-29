import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../../chat/presentation/chat_room_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});
  @override State<ContactsScreen> createState() => _ContactsScreenState();
}
class _ContactsScreenState extends State<ContactsScreen> {
  final _search = TextEditingController();
  @override void dispose() { _search.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('تواصل'), actions: [
      IconButton(tooltip: 'تحديث', onPressed: () => setState(() {}), icon: const Icon(Icons.refresh_rounded)),
    ]),
    body: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: TextField(
          controller: _search, onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'ابحث بالاسم أو اسم المستخدم...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _search.text.isEmpty ? null : IconButton(
              onPressed: () { _search.clear(); setState(() {}); },
              icon: const Icon(Icons.clear_rounded),
            ),
          ),
        ),
      ),
      Expanded(child: _users()),
    ]),
  );

  Widget _users() {
    if (Firebase.apps.isEmpty) return const Center(child: Text('خدمة الحسابات غير متاحة حاليًا'));
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').limit(100).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('تعذر تحميل المستخدمين'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final uid = FirebaseAuth.instance.currentUser?.uid;
        final query = _search.text.trim().toLowerCase();
        final users = snapshot.data!.docs.where((doc) {
          if (doc.id == uid) return false;
          final data = doc.data();
          final name = data['displayName']?.toString() ?? '';
          final username = data['username']?.toString() ?? '';
          return query.isEmpty || name.toLowerCase().contains(query) || username.toLowerCase().contains(query);
        }).toList();
        if (users.isEmpty) return const Center(child: Text('لا يوجد مستخدمون مطابقون'));
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (_, index) {
            final data = users[index].data();
            final name = data['displayName']?.toString() ?? 'مستخدم';
            final username = data['username']?.toString();
            final photo = data['photoUrl']?.toString() ?? data['photoURL']?.toString();
            return Card(child: ListTile(
              contentPadding: const EdgeInsetsDirectional.fromSTEB(12, 6, 12, 6),
              leading: CircleAvatar(backgroundImage: photo?.isNotEmpty == true ? NetworkImage(photo!) : null, child: photo?.isNotEmpty == true ? null : Text(name.characters.first)),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(username?.isNotEmpty == true ? '@$username' : 'متاح للتواصل'),
              trailing: FilledButton.tonalIcon(onPressed: () => _startChat(users[index]), icon: const Icon(Icons.chat_bubble_outline_rounded), label: const Text('رسالة')),
            ));
          },
        );
      },
    );
  }

  Future<void> _startChat(QueryDocumentSnapshot<Map<String, dynamic>> user) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى تسجيل الدخول أولًا'))); return; }
    final ids = [me.uid, user.id]..sort();
    final chatId = ids.join('_');
    final data = user.data();
    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'participants': ids,
      'participantNames': {me.uid: me.displayName ?? 'مستخدم', user.id: data['displayName'] ?? 'مستخدم'},
      'participantPhotos': {me.uid: me.photoURL ?? '', user.id: data['photoUrl'] ?? data['photoURL'] ?? ''},
      'updatedAt': FieldValue.serverTimestamp(), 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatRoomScreen(
      chatId: chatId, otherUserId: user.id,
      otherUserName: data['displayName']?.toString() ?? 'مستخدم',
      otherUserImage: data['photoUrl']?.toString() ?? data['photoURL']?.toString(),
    )));
  }
}
