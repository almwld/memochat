import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../data/social_service.dart';
import 'reels_screen.dart';
import '../../notifications/presentation/notification_center_screen.dart';
import '../../../core/widgets/user_name.dart';

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
            onPressed: () => showSearch<void>(context: context, delegate: _Search(service)),
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            tooltip: 'النشاط والإشعارات',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationCenterScreen(),
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

class _Post extends StatefulWidget {
  const _Post({required this.service, required this.id, required this.data});
  final SocialService service;
  final String id;
  final Map<String, dynamic> data;

  @override
  State<_Post> createState() => _PostState();
}

class _PostState extends State<_Post> {
  Future<void> _comment() async {
    final controller = TextEditingController();
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'التعليقات',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 260,
                  child: StreamBuilder(
                    stream: widget.service.watchPostComments(widget.id),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(child: Text('تعذر تحميل التعليقات.'));
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final comments = snapshot.data!.docs;
                      if (comments.isEmpty) {
                        return const Center(child: Text('لا توجد تعليقات بعد.'));
                      }
                      return ListView.separated(
                        itemCount: comments.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final data = comments[index].data();
                          return ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.person_rounded),
                            ),
                            title: Text(
                              data['userName']?.toString() ?? 'مستخدم Memo',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(data['text']?.toString() ?? ''),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        maxLength: 1000,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'اكتب تعليقك…',
                          counterText: '',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'إرسال التعليق',
                      onPressed: () async {
                        final text = controller.text.trim();
                        if (text.isEmpty) return;
                        try {
                          await widget.service.addPostComment(widget.id, text);
                          controller.clear();
                        } catch (error) {
                          if (sheetContext.mounted) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              SnackBar(content: Text('تعذر إرسال التعليق: $error')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _run(
    Future<void> Function() action, {
    required String message,
  }) async {
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$message: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.data['mediaUrl']?.toString() ?? '';
    final isVideo = widget.data['mediaType'] == 'video';
    final author = widget.data['authorId']?.toString() ?? '';
    final initialLikes = (widget.data['likesCount'] as num?)?.toInt() ?? 0;
    final initialComments = (widget.data['commentsCount'] as num?)?.toInt() ?? 0;
    final initialShares = (widget.data['sharesCount'] as num?)?.toInt() ?? 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
            title: UserName(
              userId: author,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text('منشور على Memo'),
            trailing: author.isEmpty || author == widget.service.currentUserId
                ? null
                : StreamBuilder(
                    stream: widget.service.watchFollowing(author),
                    builder: (context, snapshot) {
                      final following = snapshot.data?.exists == true;
                      return TextButton.icon(
                        onPressed: () => _run(
                          () => widget.service.toggleFollow(author, following),
                          message: 'تعذر تحديث المتابعة',
                        ),
                        icon: Icon(
                          following
                              ? Icons.person_remove_alt_1_rounded
                              : Icons.person_add_alt_1_rounded,
                          size: 18,
                        ),
                        label: Text(following ? 'متابَع' : 'متابعة'),
                      );
                    },
                  ),
          ),
          if (url.isNotEmpty)
            isVideo
                ? AspectRatio(aspectRatio: 16 / 9, child: _Video(url))
                : CachedNetworkImage(
                    imageUrl: url,
                    height: 270,
                    fit: BoxFit.cover,
                  ),
          if ((widget.data['text']?.toString() ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Text(
                widget.data['text'].toString(),
                style: const TextStyle(fontSize: 16, height: 1.45),
              ),
            ),
          StreamBuilder(
            stream: widget.service.watchPostLike(widget.id),
            builder: (context, likeSnapshot) {
              final liked = likeSnapshot.data?.exists == true;
              return StreamBuilder<int>(
                stream: widget.service.watchPostLikesCount(widget.id),
                initialData: initialLikes,
                builder: (context, countSnapshot) {
                  final likes = countSnapshot.data ?? initialLikes;
                  return StreamBuilder(
                    stream: widget.service.watchPostSaved(widget.id),
                    builder: (context, saveSnapshot) {
                      final saved = saveSnapshot.data?.exists == true;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: 'إعجاب',
                              onPressed: () => _run(
                                () => widget.service.togglePostLike(widget.id),
                                message: 'تعذر تسجيل الإعجاب',
                              ),
                              icon: Icon(
                                liked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: liked
                                    ? Theme.of(context).colorScheme.error
                                    : null,
                              ),
                            ),
                            Text('$likes'),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'تعليق',
                              onPressed: _comment,
                              icon: const Icon(Icons.mode_comment_outlined),
                            ),
                            Text('$initialComments'),
                            const Spacer(),
                            IconButton(
                              tooltip: 'مشاركة',
                              onPressed: () => _run(
                                () => widget.service.sharePost(widget.id),
                                message: 'تعذر مشاركة المنشور',
                              ),
                              icon: const Icon(Icons.share_outlined),
                            ),
                            Text('$initialShares'),
                            IconButton(
                              tooltip: saved ? 'إلغاء الحفظ' : 'حفظ',
                              onPressed: () => _run(
                                () => widget.service.togglePostSave(widget.id, saved),
                                message: 'تعذر تحديث الحفظ',
                              ),
                              icon: Icon(
                                saved
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
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
  _Search(this.service);
  final SocialService service;

  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear)),
      ];

  @override
  Widget? buildLeading(BuildContext context) =>
      BackButton(onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) {
    final needle = query.trim();
    if (needle.isEmpty) {
      return const Center(child: Text('اكتب اسمًا أو كلمة للبحث'));
    }
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: service.searchContent(needle),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('تعذر تنفيذ البحث.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final results = snapshot.data!;
        if (results.isEmpty) {
          return const Center(child: Text('لا توجد نتائج مطابقة.'));
        }
        return ListView.separated(
          itemCount: results.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, index) {
            final item = results[index];
            final isReel = item['collection'] == 'socialReels';
            final title = item['authorName']?.toString().trim().isNotEmpty == true
                ? item['authorName'].toString()
                : 'مستخدم Memo';
            final body = (item['text'] ?? item['caption'] ?? '').toString().trim();
            return ListTile(
              leading: CircleAvatar(
                child: Icon(isReel ? Icons.play_arrow_rounded : Icons.article_outlined),
              ),
              title: Text(title),
              subtitle: Text(
                body.isEmpty ? (isReel ? 'ريل' : 'منشور') : body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) => buildResults(context);
}
