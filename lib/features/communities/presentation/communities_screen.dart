import 'package:flutter/material.dart';

import '../data/community_service.dart';

class CommunitiesScreen extends StatelessWidget {
  const CommunitiesScreen({super.key, this.service});
  final CommunityService? service;
  CommunityService get _service => service ?? CommunityService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.groups_rounded)),
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
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر إنشاء المجتمع.')));
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: widget.service.watchPosts(communityId: widget.communityId, channelId: widget.channelId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final posts = snapshot.data!.docs;
                if (posts.isEmpty) return const Center(child: Text('لا توجد منشورات بعد.'));
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: posts.length,
                  itemBuilder: (_, index) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(posts[index].data()['text']?.toString() ?? ''),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: Row(
                children: [
                  Expanded(child: TextField(controller: _controller, minLines: 1, maxLines: 4, decoration: const InputDecoration(hintText: 'منشور جديد...'))),
                  IconButton(
                    onPressed: () async {
                      final text = _controller.text;
                      _controller.clear();
                      try {
                        await widget.service.sendChannelPost(communityId: widget.communityId, channelId: widget.channelId, text: text);
                      } catch (_) {}
                    },
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
