import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../data/social_service.dart';
import 'reels_screen.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key, this.service});
  final SocialService? service;

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> with SingleTickerProviderStateMixin {
  late final SocialService service = widget.service ?? SocialService();
  late final TabController tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  void _compose() {
    final isReelsTab = tabs.index == 1;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _Composer(service: service, initialReel: isReelsTab),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memo', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'بحث',
            onPressed: () => showSearch<void>(context: context, delegate: _Search()),
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            tooltip: 'النشاط',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const AlertDialog(
                title: Text('نشاط Memo'),
                content: Text('الإعجابات والتعليقات والمشاركات والمتابعات ستظهر هنا.'),
              ),
            ),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
        bottom: TabBar(
          controller: tabs,
          tabs: const [
            Tab(icon: Icon(Icons.dynamic_feed_rounded), text: 'المنشورات'),
            Tab(icon: Icon(Icons.play_circle_outline_rounded), text: 'الريلز'),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabs,
        children: [
          _Feed(service: service),
          ReelsScreen(service: service),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 86),
        child: FloatingActionButton.extended(
          heroTag: 'memo-community-create',
          tooltip: 'إضافة محتوى',
          onPressed: _compose,
          icon: const Icon(Icons.add_rounded),
          label: Text(tabs.index == 1 ? 'إضافة ريل' : 'إضافة منشور'),
        ),
      ),
    );
  }
}

class _Feed extends StatelessWidget {
  const _Feed({required this.service});
  final SocialService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: service.posts(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('تعذر تحميل المنشورات.'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('لا توجد منشورات بعد. كن أول من ينشر في Memo.'));
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
          itemCount: docs.length,
          itemBuilder: (_, i) => _Post(service: service, id: docs[i].id, data: docs[i].data()),
        );
      },
    );
  }
}

class _Post extends StatelessWidget {
  const _Post({required this.service, required this.id, required this.data});
  final SocialService service;
  final String id;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final url = data['mediaUrl']?.toString() ?? '';
    final isVideo = data['mediaType'] == 'video';
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
            title: Text(data['authorId']?.toString() ?? 'مستخدم Memo', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('منشور على Memo'),
          ),
          if (url.isNotEmpty)
            isVideo
                ? AspectRatio(aspectRatio: 16 / 9, child: _Video(url))
                : CachedNetworkImage(imageUrl: url, height: 270, fit: BoxFit.cover),
          if ((data['text']?.toString() ?? '').isNotEmpty)
            Padding(padding: const EdgeInsets.all(16), child: Text(data['text'].toString(), style: const TextStyle(fontSize: 16, height: 1.45))),
        ],
      ),
    );
  }
}

class _Video extends StatefulWidget {
  const _Video(this.url);
  final String url;

  @override
  State<_Video> createState() => _VideoState();
}

class _VideoState extends State<_Video> {
  late final VideoPlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) return const AspectRatio(aspectRatio: 16 / 9, child: Center(child: CircularProgressIndicator()));
    return AspectRatio(aspectRatio: 16 / 9, child: VideoPlayer(controller));
  }
}

class _Composer extends StatefulWidget {
  const _Composer({required this.service, this.initialReel = false});
  final SocialService service;
  final bool initialReel;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  late bool reel = widget.initialReel;
  final text = TextEditingController();
  final picker = ImagePicker();
  File? media;
  bool busy = false;

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    final result = await picker.pickImage(source: ImageSource.gallery, imageQuality: 88);
    if (result != null && mounted) setState(() => media = File(result.path));
  }

  Future<void> pickVideo() async {
    final result = await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 90));
    if (result != null && mounted) setState(() => media = File(result.path));
  }

  Future<void> publish() async {
    if (media == null && text.text.trim().isEmpty) return;
    setState(() => busy = true);
    try {
      if (reel) {
        final video = media;
        if (video == null) throw StateError('اختر فيديو للريل');
        await widget.service.createReel(video: video, caption: text.text);
      } else {
        final file = media;
        final isVideo = file != null && RegExp(r'\.(mp4|mov|m4v)$', caseSensitive: false).hasMatch(file.path);
        await widget.service.createPost(text: text.text, media: file, video: isVideo);
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر النشر: $error')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('إنشاء محتوى في Memo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('منشور'), icon: Icon(Icons.article_outlined)),
              ButtonSegment(value: true, label: Text('ريل'), icon: Icon(Icons.video_library_outlined)),
            ],
            selected: {reel},
            onSelectionChanged: (value) => setState(() => reel = value.first),
          ),
          TextField(controller: text, maxLength: 5000, maxLines: 5, decoration: const InputDecoration(hintText: 'ما الذي تريد مشاركته؟')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: reel ? pickVideo : pickImage,
            icon: Icon(reel ? Icons.video_library_rounded : Icons.photo_library_rounded),
            label: Text(reel ? 'اختيار فيديو' : 'اختيار صورة'),
          ),
          if (!reel)
            OutlinedButton.icon(onPressed: pickVideo, icon: const Icon(Icons.videocam_outlined), label: const Text('إضافة فيديو')),
          if (media != null)
            Padding(padding: const EdgeInsets.all(8), child: Text(media!.path.split(Platform.pathSeparator).last, maxLines: 1, overflow: TextOverflow.ellipsis)),
          FilledButton.icon(
            onPressed: busy ? null : publish,
            icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.publish_rounded),
            label: Text(busy ? 'جارٍ النشر...' : 'نشر'),
          ),
        ],
      ),
    );
  }
}

class _Search extends SearchDelegate<void> {
  @override
  List<Widget>? buildActions(BuildContext context) => [IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear))];
  @override
  Widget? buildLeading(BuildContext context) => BackButton(onPressed: () => close(context, null));
  @override
  Widget buildResults(BuildContext context) => Center(child: Text(query.isEmpty ? 'ابحث عن أشخاص ومنشورات' : 'بحث Memo: $query'));
  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);
}
