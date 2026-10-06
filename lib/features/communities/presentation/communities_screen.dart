import 'package:flutter/material.dart';
import '../../../core/widgets/premium_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/community_service.dart';

class CommunitiesScreen extends StatelessWidget {
  const CommunitiesScreen({super.key, this.service});
  final CommunityService? service;
  CommunityService get _service => service ?? CommunityService();

  @override
  Widget build(BuildContext context) {
    return ScrollAwareScaffold(
      appBar: AppBar(
        title: const Text('المجتمعات', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'إنشاء مجتمع',
            onPressed: () => _createCommunity(context),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: _service.watchPublicCommunities(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('تعذر تحميل المجتمعات.'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('لا توجد مجتمعات عامة بعد.'));
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final description = data['description']?.toString() ?? '';
              final members = data['membersCount'] ?? 0;
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(width: 52, height: 52, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(.10), borderRadius: BorderRadius.circular(16)), child: Icon(Icons.groups_rounded, color: Theme.of(context).colorScheme.primary)),
                  title: Text(data['name']?.toString() ?? 'مجتمع', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(description.isNotEmpty ? description : '$members أعضاء', maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => _openCommunity(context, docs[index].id, data['name']?.toString() ?? 'مجتمع'),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _createCommunity(BuildContext context) async {
    final name = TextEditingController();
    final description = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنشاء مجتمع'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, maxLength: 80, decoration: const InputDecoration(labelText: 'اسم المجتمع')),
            TextField(controller: description, maxLength: 500, maxLines: 3, decoration: const InputDecoration(labelText: 'الوصف')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إنشاء')),
        ],
      ),
    );
    if (result != true) {
      name.dispose();
      description.dispose();
      return;
    }
    try {
      final id = await _service.createCommunity(name: name.text, description: description.text);
      if (context.mounted) await _openCommunity(context, id, name.text.trim());
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إنشاء المجتمع: ' + e.toString().replaceFirst('Bad state: ', ''))));
    } finally {
      name.dispose();
      description.dispose();
    }
  }

  Future<void> _openCommunity(BuildContext context, String id, String name) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CommunityDetailScreen(communityId: id, name: name, service: _service),
    ));
  }
}

class CommunityDetailScreen extends StatelessWidget {
  const CommunityDetailScreen({required this.communityId, required this.name, required this.service, super.key});
  final String communityId;
  final String name;
  final CommunityService service;

  Future<void> _inviteUser(BuildContext context) async {
    final snap = await FirebaseFirestore.instance.collection('users').limit(100).get();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final candidates = snap.docs.where((doc) => doc.id != uid && doc.data()['hideFromContacts'] != true).toList();
    if (!context.mounted) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        itemCount: candidates.length,
        itemBuilder: (_, index) {
          final doc = candidates[index];
          final d = doc.data();
          final name = d['displayName']?.toString().trim().isNotEmpty == true ? d['displayName'].toString().trim() : 'مستخدم';
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(name),
            onTap: () => Navigator.pop(context, doc.id),
          );
        },
      ),
    );
    if (selected == null) return;
    try {
      await service.inviteToCommunity(communityId: communityId, recipientId: selected);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال دعوة المجتمع.')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال الدعوة: $e')));
    }
  }

  Future<void> _createChannel(BuildContext context) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنشاء قناة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, maxLength: 80, decoration: const InputDecoration(labelText: 'اسم القناة')),
            TextField(controller: descriptionController, maxLength: 300, decoration: const InputDecoration(labelText: 'الوصف')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إنشاء')),
        ],
      ),
    );
    if (result == true) {
      try {
        await service.createChannel(
          communityId: communityId,
          name: nameController.text,
          description: descriptionController.text,
        );
      } catch (_) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر إنشاء القناة.')));
      }
    }
    nameController.dispose();
    descriptionController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
            tooltip: 'دعوة عضو',
            onPressed: () => _inviteUser(context),
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
          IconButton(
            tooltip: 'إنشاء قناة',
            onPressed: () => _createChannel(context),
            icon: const Icon(Icons.add_comment_rounded),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: service.watchChannels(communityId),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('تعذر تحميل القنوات.'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            itemCount: docs.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.group_add_rounded),
                    title: const Text('الانضمام إلى المجتمع'),
                    subtitle: const Text('انضم للوصول إلى النقاشات.'),
                    onTap: () async {
                      try {
                        await service.joinCommunity(communityId);
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الانضمام إلى المجتمع.')));
                      } catch (_) {}
                    },
                  ),
                );
              }
              final data = docs[index - 1].data();
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.tag_rounded),
                  title: Text(data['name']?.toString() ?? 'قناة'),
                  subtitle: Text(data['description']?.toString() ?? ''),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ChannelScreen(
                      communityId: communityId,
                      channelId: docs[index - 1].id,
                      name: data['name']?.toString() ?? 'قناة',
                      service: service,
                    ),
                  )),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ChannelScreen extends StatefulWidget {
  const ChannelScreen({required this.communityId, required this.channelId, required this.name, required this.service, super.key});
  final String communityId;
  final String channelId;
  final String name;
  final CommunityService service;

  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: scheme.primary.withOpacity(.10), borderRadius: BorderRadius.circular(13)), child: Icon(Icons.forum_rounded, color: scheme.primary)),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900))),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: StreamBuilder(
            stream: widget.service.watchPosts(communityId: widget.communityId, channelId: widget.channelId),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text('تعذر تحميل رسائل الغرفة.'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final posts = snapshot.data!.docs;
              if (posts.isEmpty) return const Center(child: Text('ابدأ أول رسالة في هذه الغرفة.'));
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
                itemCount: posts.length,
                itemBuilder: (_, index) {
                  final data = posts[index].data();
                  final mine = data['authorId']?.toString() == FirebaseAuth.instance.currentUser?.uid;
                  return Align(
                    alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 330),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: mine ? scheme.primary : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(data['text']?.toString() ?? '', style: TextStyle(color: mine ? scheme.onPrimary : scheme.onSurface, height: 1.35)),
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
            child: Row(children: [
              Expanded(child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'اكتب رسالة في الغرفة...',
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                ),
              )),
              const SizedBox(width: 6),
              IconButton.filled(
                tooltip: 'إرسال',
                onPressed: () async {
                  final text = _controller.text.trim();
                  if (text.isEmpty) return;
                  _controller.clear();
                  try {
                    await widget.service.sendChannelPost(communityId: widget.communityId, channelId: widget.channelId, text: text);
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الإرسال: $e')));
                  }
                },
                icon: const Icon(Icons.send_rounded),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
