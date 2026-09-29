// ignore_for_file: prefer_interpolation_to_compose_strings
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_room_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _search = TextEditingController();
  int _tab = 0;

  Stream<QuerySnapshot<Map<String, dynamic>>> _chats() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return FirebaseFirestore.instance.collection('chats')
        .where('participants', arrayContains: uid).snapshots();
  }

  @override void dispose() { _search.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0B1121) : const Color(0xFFF7FAFA),
      appBar: AppBar(
        title: const Text('الدردشة', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true, backgroundColor: const Color(0xFF0A8F83), foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 10), height: 48,
            decoration: BoxDecoration(color: dark ? const Color(0xFF162039) : Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [_tabButton('المحادثات', 0), _tabButton('المكالمات', 1), _tabButton('تواصل', 2)]),
          ),
        ),
      ),
      body: _tab == 0 ? _conversations(dark) : (_tab == 1 ? _calls() : _contacts(dark)),
      floatingActionButton: _tab == 0
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF0A8F83),
              onPressed: () => setState(() => _tab = 2),
              child: const Icon(Icons.chat_rounded, color: Colors.white),
            )
          : null,
    );
  }

  Widget _tabButton(String label, int index) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _tab == index ? const Color(0xFF0A8F83) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(label, style: TextStyle(
              color: _tab == index ? Colors.white : Colors.grey,
              fontWeight: FontWeight.w700,
            )),
          ),
        ),
      ),
    );
  }

  Widget _conversations(bool dark) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'ابحث في محادثاتك...', prefixIcon: const Icon(Icons.search),
            filled: true, fillColor: dark ? const Color(0xFF162039) : Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
          ),
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _chats(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('تعذر تحميل المحادثات: ' + snapshot.error.toString()));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF0A8F83)));
            final q = _search.text.trim().toLowerCase();
            final docs = snapshot.data!.docs.where((doc) {
              final last = doc.data()['lastMessage']?.toString().toLowerCase() ?? '';
              return q.isEmpty || last.contains(q);
            }).toList();
            if (docs.isEmpty) return const Center(child: Text('لا توجد محادثات بعد'));
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _chatTile(docs[i], dark),
            );
          },
        ),
      ),
    ]);
  }

  Widget _chatTile(DocumentSnapshot<Map<String, dynamic>> doc, bool dark) {
    final data = doc.data() ?? <String, dynamic>{};
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final ids = List<String>.from(data['participants'] ?? const []);
    final other = ids.firstWhere((id) => id != uid, orElse: () => '');
    final names = Map<String, dynamic>.from(data['participantNames'] ?? {});
    final photos = Map<String, dynamic>.from(data['participantPhotos'] ?? {});
    final name = names[other]?.toString() ?? 'مستخدم';
    final photo = photos[other]?.toString();

    return Card(
      elevation: 0, color: dark ? const Color(0xFF162039) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: CircleAvatar(
          radius: 28,
          backgroundImage: photo?.isNotEmpty == true ? NetworkImage(photo!) : null,
          child: photo?.isNotEmpty == true ? null : const Icon(Icons.person, color: Color(0xFF0A8F83)),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(data['lastMessage']?.toString() ?? 'اضغط لفتح المحادثة', maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_left),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomScreen(
              chatId: doc.id, otherUserId: other, otherUserName: name, otherUserImage: photo,
            ),
          ),
        ),
      ),
    );
  }

  Widget _calls() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('تسجيل الدخول مطلوب'));
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('calls').where('receiverId', isEqualTo: uid).limit(50).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text('لا توجد مكالمات'));
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, i) {
            final data = snapshot.data!.docs[i].data();
            return ListTile(
              leading: CircleAvatar(child: Icon(data['isVideo'] == true ? Icons.videocam : Icons.call)),
              title: Text(data['callerName']?.toString() ?? 'مستخدم'),
              subtitle: Text(data['status']?.toString() ?? ''),
            );
          },
        );
      },
    );
  }

  Widget _contacts(bool dark) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'ابحث عن مستخدم للبدء...', prefixIcon: const Icon(Icons.search),
            filled: true, fillColor: dark ? const Color(0xFF162039) : Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
          ),
        ),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').limit(50).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
            final q = _search.text.trim().toLowerCase();
            final users = snapshot.data!.docs.where((doc) {
              final data = doc.data();
              final hay = (data['displayName']?.toString() ?? '') + ' ' + (data['email']?.toString() ?? '');
              return doc.id != uid && hay.toLowerCase().contains(q);
            }).toList();
            return ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, i) {
                final data = users[i].data();
                return ListTile(
                  leading: CircleAvatar(child: Text((data['displayName']?.toString() ?? 'م').characters.first)),
                  title: Text(data['displayName']?.toString() ?? 'مستخدم'),
                  subtitle: Text(data['email']?.toString() ?? ''),
                  trailing: const Icon(Icons.chat, color: Color(0xFF0A8F83)),
                  onTap: () => _startChat(users[i]),
                );
              },
            );
          },
        ),
      ),
    ]);
  }

  Future<void> _startChat(QueryDocumentSnapshot<Map<String, dynamic>> user) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    final ids = [me.uid, user.id]..sort();
    final chatId = ids.join('_');
    final data = user.data();
    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'participants': ids,
      'participantNames': {me.uid: me.displayName ?? 'مستخدم', user.id: data['displayName'] ?? 'مستخدم'},
      'participantPhotos': {me.uid: me.photoURL ?? '', user.id: data['photoUrl'] ?? data['photoURL'] ?? ''},
      'lastMessage': '', 'updatedAt': FieldValue.serverTimestamp(), 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          chatId: chatId, otherUserId: user.id,
          otherUserName: data['displayName']?.toString() ?? 'مستخدم',
          otherUserImage: data['photoUrl']?.toString(),
        ),
      ),
    );
  }
}
