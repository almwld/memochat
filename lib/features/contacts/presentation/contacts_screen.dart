import '../../../core/models/chat_user.dart';
import '../../../core/repositories/chat_repository.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/premium_ui.dart';
import '../../chat/presentation/chat_room_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({required this.repository, super.key});
  final ChatRepository repository;
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
    return StreamBuilder<List<ChatUser>>(
      stream: widget.repository.watchContacts(query: _search.text),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SliverFillRemaining(hasScrollBody: false, child: _ContactState(title: 'تعذر تحميل الحسابات', subtitle: 'تحقق من الاتصال والصلاحيات.'));
        if (!snapshot.hasData) return const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()));
        final users = snapshot.data!;
        if (users.isEmpty) return const SliverFillRemaining(hasScrollBody: false, child: _ContactState(title: 'لا يوجد مستخدمون مطابقون', subtitle: 'جرّب اسمًا آخر أو اسم المستخدم.'));
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
          sliver: SliverList.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsetsDirectional.fromSTEB(12, 8, 10, 8),
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundImage: user.avatarUrl?.isNotEmpty == true ? NetworkImage(user.avatarUrl!) : null,
                      child: user.avatarUrl?.isNotEmpty == true ? null : Text(user.displayName.characters.first),
                    ),
                    title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(user.username?.isNotEmpty == true ? '@${user.username}' : (user.isOnline ? 'متصل الآن' : 'متاح للتواصل')),
                    trailing: FilledButton.tonalIcon(onPressed: () => _startChat(user), icon: const AppIcon(AppIcons.chat, size: 18), label: const Text('رسالة')),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _startChat(ChatUser user) async {
    try {
      await widget.repository.createConversation(otherUserId: user.id, otherUserName: user.displayName, otherUserPhoto: user.avatarUrl);
      if (!mounted) return;
      final ids = <String>[user.id];
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatRoomScreen(
        chatId: ids.join('_'),
        otherUserId: user.id,
        otherUserName: user.displayName,
        otherUserImage: user.avatarUrl,
      )));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر إنشاء المحادثة. تحقق من الاتصال والصلاحيات.')));
    }
  }}

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
