import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/chat_user.dart';
import '../../../core/privacy/privacy_service.dart';
import '../../../core/repositories/chat_repository.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/premium_ui.dart';
import '../../../core/services/friend_request_service.dart';
import '../../chat/presentation/chat_navigation.dart';
import '../../communities/presentation/communities_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({required this.repository, super.key});
  final ChatRepository repository;
  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _search = TextEditingController();
  final _privacy = PrivacyService();
  final _friendRequests = FriendRequestService();
  Set<String> _blocked = <String>{};
  Set<String> _friends = <String>{};
  StreamSubscription<Set<String>>? _friendsSub;

  @override
  void initState() {
    super.initState();
    _loadBlocked();
    _friendsSub = _friendRequests.watchActiveFriendIds().listen((ids) {
      if (mounted) setState(() => _friends = ids);
    }, onError: (_) {});
  }

  @override
  void dispose() { _friendsSub?.cancel(); _search.dispose(); super.dispose(); }

  Future<void> _loadBlocked() async {
    try {
      final blocked = await _privacy.getBlockedUserIds();
      if (mounted) setState(() => _blocked = blocked);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('تواصل', style: TextStyle(fontWeight: FontWeight.w900)),
      actions: [
        IconButton(
          tooltip: 'المجتمعات',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CommunitiesScreen()),
          ),
          icon: const Icon(Icons.groups_rounded),
        ),
        IconButton(
          tooltip: 'طلبات الصداقة',
          onPressed: _showFriendRequests,
          icon: const Icon(Icons.person_add_alt_1_rounded),
        ),
        IconButton(
          tooltip: 'تحديث',
          onPressed: () { _loadBlocked(); setState(() {}); },
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
                hintText: 'ابحث بالاسم أو @memo_معرّف...',
                prefixIcon: AppIcon(AppIcons.search, size: 21),
              ),
            ),
          ),
        ),
        _users(),
      ],
    ),
  );

  Widget _users() => StreamBuilder<List<ChatUser>>(
    stream: widget.repository.watchContacts(query: _search.text),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const SliverFillRemaining(
          hasScrollBody: false,
          child: _ContactState(title: 'تعذر تحميل الحسابات', subtitle: 'تحقق من الاتصال والصلاحيات.'),
        );
      }
      if (!snapshot.hasData) {
        return const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()));
      }
      final users = snapshot.data!.where((user) => !_blocked.contains(user.id)).toList();
      if (users.isEmpty) {
        return const SliverFillRemaining(
          hasScrollBody: false,
          child: _ContactState(title: 'لا يوجد مستخدمون مطابقون', subtitle: 'جرّب اسمًا آخر أو اسم المستخدم.'),
        );
      }
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
                  contentPadding: const EdgeInsetsDirectional.fromSTEB(12, 8, 6, 8),
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundImage: user.avatarUrl?.isNotEmpty == true ? NetworkImage(user.avatarUrl!) : null,
                    child: user.avatarUrl?.isNotEmpty == true ? null : Text(user.displayName.characters.first),
                  ),
                  title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(user.username?.isNotEmpty == true ? '@${user.username}' : (user.isOnline ? 'متصل الآن' : 'متاح للتواصل')),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => _handleUserAction(value, user),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'message', child: Text('رسالة')),
                      if (_friends.contains(user.id))
                        const PopupMenuItem(value: 'unfriend', child: Text('إزالة من الأصدقاء'))
                      else
                        const PopupMenuItem(value: 'friend', child: Text('إضافة إلى الأصدقاء')),
                      const PopupMenuItem(value: 'block', child: Text('حظر')),
                      const PopupMenuItem(value: 'report', child: Text('إبلاغ')),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );

  Future<void> _handleUserAction(String value, ChatUser user) async {
    if (value == 'unfriend') {
      try {
        await _friendRequests.removeFriend(user.id);
        if (mounted) {
          setState(() => _friends = {..._friends}..remove(user.id));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تمت إزالة الصديق.')),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر إزالة الصديق.')),
          );
        }
      }
      return;
    }
    if (value == 'friend') {
      try {
        await _friendRequests.send(recipientId: user.id, recipientName: user.displayName);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال طلب الصداقة.')));
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر إرسال طلب الصداقة.')));
      }
      return;
    }
    if (value == 'message') {
      await _startChat(user);
      return;
    }
    if (value == 'block') {
      try {
        await _privacy.blockUser(user.id);
        if (!mounted) return;
        setState(() => _blocked = {..._blocked, user.id});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حظر المستخدم.')));
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تنفيذ الحظر.')));
      }
      return;
    }
    final reason = await _askReportReason(user.displayName);
    if (reason == null) return;
    try {
      await _privacy.reportUser(userId: user.id, reason: reason);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال البلاغ.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر إرسال البلاغ.')));
    }
  }

  Future<String?> _askReportReason(String name) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('الإبلاغ عن $name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 500,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'اذكر سبب البلاغ'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('إرسال')),
        ],
      ),
    );
    controller.dispose();
    return result?.isEmpty == true ? null : result;
  }

  Future<void> _showFriendRequests() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StreamBuilder(
        stream: _friendRequests.watchIncoming(),
        builder: (context, snapshot) {
          final docs = (snapshot.data?.docs ?? const []).where((doc) => doc.data()['state'] == FriendRequestState.pending.name).toList(growable: false);
          if (docs.isEmpty) {
            return const SafeArea(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: Text('لا توجد طلبات صداقة جديدة.')),
              ),
            );
          }
          return SafeArea(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final data = docs[index].data();
                final id = docs[index].id;
                final name = data['senderName']?.toString().trim();
                final senderId = data['senderId']?.toString() ?? '';
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person_add_alt_1_rounded)),
                  title: Text(name?.isNotEmpty == true ? name! : 'طلب صداقة'),
                  subtitle: Text(senderId),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        tooltip: 'قبول',
                        icon: const Icon(Icons.check_rounded),
                        onPressed: () async {
                          await _friendRequests.accept(id);
                          if (context.mounted) Navigator.pop(context);
                        },
                      ),
                      IconButton(
                        tooltip: 'رفض',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () async {
                          await _friendRequests.reject(id);
                          if (context.mounted) Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _startChat(ChatUser user) async {
    try {
      final chatId = await widget.repository.createConversation(
        otherUserId: user.id,
        otherUserName: user.displayName,
        otherUserPhoto: user.avatarUrl,
      );
      if (!mounted) return;
      await ChatNavigation.openRoom(
        context,
        chatId: chatId,
        otherUserId: user.id,
        otherUserName: user.displayName,
        otherUserImage: user.avatarUrl,
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر إنشاء المحادثة. تحقق من الاتصال والصلاحيات.')));
    }
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
