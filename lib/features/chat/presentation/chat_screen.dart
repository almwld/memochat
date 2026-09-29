import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_room_screen.dart';
import '../../../core/repositories/chat_repository.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({required this.repository, super.key});
  final ChatRepository repository;
  @override State<ChatScreen> createState() => _ChatScreenState();
}
class _ChatScreenState extends State<ChatScreen> {
  final _search = TextEditingController();
  Stream<QuerySnapshot<Map<String, dynamic>>> _chats() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return FirebaseFirestore.instance.collection('chats').where('participants', arrayContains: uid).snapshots();
  }
  @override void dispose() { _search.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('المحادثات', style: TextStyle(fontWeight: FontWeight.w800))),
    body: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: TextField(
          controller: _search, onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'ابحث في محادثاتك...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _search.text.isEmpty ? null : IconButton(onPressed: () { _search.clear(); setState(() {}); }, icon: const Icon(Icons.clear_rounded)),
          ),
        ),
      ),
      Expanded(child: _conversationList()),
    ]),
  );

  Widget _conversationList() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('يرجى تسجيل الدخول لعرض المحادثات'));
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _chats(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('تعذر تحميل المحادثات'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final query = _search.text.trim().toLowerCase();
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data();
          final last = data['lastMessage']?.toString() ?? '';
          final names = Map<String, dynamic>.from(data['participantNames'] as Map? ?? const {});
          final ids = List<String>.from(data['participants'] ?? const []);
          final other = ids.firstWhere((id) => id != uid, orElse: () => '');
          final name = names[other]?.toString() ?? '';
          return query.isEmpty || last.toLowerCase().contains(query) || name.toLowerCase().contains(query);
        }).toList();
        if (docs.isEmpty) return const Center(child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('لا توجد محادثات بعد\nمن «تواصل» اختر مستخدمًا وابدأ محادثة جديدة.', textAlign: TextAlign.center),
        ));
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _tile(docs[i], uid),
        );
      },
    );
  }

  Widget _tile(DocumentSnapshot<Map<String, dynamic>> doc, String uid) {
    final data = doc.data() ?? <String, dynamic>{};
    final ids = List<String>.from(data['participants'] ?? const []);
    final other = ids.firstWhere((id) => id != uid, orElse: () => '');
    final names = Map<String, dynamic>.from(data['participantNames'] as Map? ?? const {});
    final photos = Map<String, dynamic>.from(data['participantPhotos'] as Map? ?? const {});
    final name = names[other]?.toString() ?? 'مستخدم';
    final photo = photos[other]?.toString();
    return Card(child: ListTile(
      contentPadding: const EdgeInsetsDirectional.fromSTEB(12, 7, 12, 7),
      leading: CircleAvatar(radius: 27, backgroundImage: photo?.isNotEmpty == true ? NetworkImage(photo!) : null, child: photo?.isNotEmpty == true ? null : const Icon(Icons.person_rounded)),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(data['lastMessage']?.toString().isNotEmpty == true ? data['lastMessage'].toString() : 'ابدأ المحادثة', maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_left_rounded),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatRoomScreen(
        chatId: doc.id, otherUserId: other, otherUserName: name, otherUserImage: photo,
      ))),
    ));
  }
}
