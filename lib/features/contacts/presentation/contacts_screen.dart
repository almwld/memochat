import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/premium_ui.dart';
import '../../chat/presentation/chat_room_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});
  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _search = TextEditingController();

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('تواصل', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: PremiumHero(
                  icon: AppIcons.contacts,
                  title: 'اكتشف وتواصل',
                  subtitle: 'ابحث عن الأشخاص، شاهد حالتهم وابدأ محادثة أو مكالمة مباشرة.',
                  action: const SizedBox.shrink(),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'ابحث بالاسم أو اسم المستخدم...',
                    prefixIcon: AppIcon(AppIcons.search, size: 21),
                  ),
                ),
              ),
            ),
            _users(),
          ],
        ),
      );

  Widget _users() {
    if (Firebase.apps.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: _ContactState(
          title: 'جاري تهيئة الحسابات',
          subtitle: 'تتم تهيئة الاتصال بالخدمة تلقائيًا. لا حاجة لإعادة تشغيل التطبيق.',
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').limit(100).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: _ContactState(
              title: 'تعذر تحميل الحسابات',
              subtitle: 'تحقق من الاتصال وقواعد الوصول ثم حاول مرة أخرى.',
            ),
          );
        }
        if (!snapshot.hasData) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final uid = FirebaseAuth.instance.currentUser?.uid;
        final query = _search.text.trim().toLowerCase();
        final users = snapshot.data!.docs.where((doc) {
          if (doc.id == uid) return false;
          final data = doc.data();
          final name = data['displayName']?.toString() ?? '';
          final username = data['username']?.toString() ?? '';
          return query.isEmpty ||
              name.toLowerCase().contains(query) ||
              username.toLowerCase().contains(query);
        }).toList();

        if (users.isEmpty) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: _ContactState(
              title: 'لا يوجد مستخدمون مطابقون',
              subtitle: 'جرّب اسمًا آخر أو اسم المستخدم.',
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
          sliver: SliverList.separated(
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final doc = users[index];
              final data = doc.data();
              final name = data['displayName']?.toString() ?? 'مستخدم';
              final username = data['username']?.toString();
              final photo = data['photoUrl']?.toString() ?? data['photoURL']?.toString();
              final online = data['isOnline'] == true;

              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsetsDirectional.fromSTEB(12, 8, 10, 8),
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: photo?.isNotEmpty == true ? NetworkImage(photo!) : null,
                        child: photo?.isNotEmpty == true
                            ? null
                            : Text(name.characters.first, style: const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                      if (online)
                        PositionedDirectional(
                          end: 0,
                          bottom: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: const Color(0xFF28B86B),
                              shape: BoxShape.circle,
                              border: Border.all(color: Theme.of(context).cardColor, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(username?.isNotEmpty == true ? '@$username' : (online ? 'متصل الآن' : 'متاح للتواصل')),
                  trailing: FilledButton.tonalIcon(
                    onPressed: () => _startChat(doc),
                    icon: const AppIcon(AppIcons.chat, size: 18),
                    label: const Text('رسالة'),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _startChat(QueryDocumentSnapshot<Map<String, dynamic>> user) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جارٍ تجهيز الحساب، حاول مرة أخرى.')));
      return;
    }

    final ids = [me.uid, user.id]..sort();
    final chatId = ids.join('_');
    final data = user.data();

    try {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).set(
        {
          'participants': ids,
          'participantNames': {
            me.uid: me.displayName ?? 'مستخدم',
            user.id: data['displayName'] ?? 'مستخدم',
          },
          'participantPhotos': {
            me.uid: me.photoURL ?? '',
            user.id: data['photoUrl'] ?? data['photoURL'] ?? '',
          },
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر إنشاء المحادثة. تحقق من الاتصال والصلاحيات.')),
        );
      }
      return;
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          chatId: chatId,
          otherUserId: user.id,
          otherUserName: data['displayName']?.toString() ?? 'مستخدم',
          otherUserImage: data['photoUrl']?.toString() ?? data['photoURL']?.toString(),
        ),
      ),
    );
  }
}

class _ContactState extends StatelessWidget {
  const _ContactState({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const PremiumIconTile(icon: AppIcons.contacts, size: 76, iconSize: 36),
              const SizedBox(height: 18),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5)),
            ],
          ),
        ),
      );
}
