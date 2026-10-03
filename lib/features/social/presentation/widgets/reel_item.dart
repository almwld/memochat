import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../data/social_service.dart';
import 'comment_sheet.dart';
import 'reel_actions.dart';
import 'reel_caption.dart';
import 'reel_edit_dialog.dart';

class ReelItem extends StatefulWidget {
  const ReelItem({
    super.key,
    required this.service,
    required this.id,
    required this.data,
    required this.active,
  });

  final SocialService service;
  final String id;
  final Map<String, dynamic> data;
  final bool active;

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> with SingleTickerProviderStateMixin {
  VideoPlayerController? _player;
  bool _liked = false;
  bool _saved = false;
  bool _following = false;
  bool _showHeart = false;
  bool _viewRecorded = false;

  @override
  void initState() {
    super.initState();
    _liked = false;
    _loadState();
    _initPlayer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.active && !_viewRecorded) {
        _viewRecorded = true;
        widget.service.recordView(widget.id).catchError((_) {});
      }
    });
  }

  Future<void> _loadState() async {
    try {
      if (!mounted) return;
    } catch (_) {}
  }

  Future<void> _initPlayer() async {
    final url = widget.data['videoUrl']?.toString() ?? '';
    if (url.isEmpty) return;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _player = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      if (widget.active) await controller.play();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant ReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      if (widget.active) {
        _player?.play();
        if (!_viewRecorded) {
          _viewRecorded = true;
          widget.service.recordView(widget.id).catchError((_) {});
        }
      } else {
        _player?.pause();
      }
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final player = _player;
    if (player == null || !player.value.isInitialized) return;
    setState(() {
      if (player.value.isPlaying) {
        player.pause();
      } else {
        player.play();
      }
    });
  }

  bool _isTransientFirestoreError(Object error) {
    return error is FirebaseException &&
        (error.code == 'unavailable' ||
            error.code == 'deadline-exceeded' ||
            error.code == 'aborted');
  }

  Future<void> _runInteraction(
    Future<void> Function() action, {
    String message = 'تعذر تنفيذ العملية حالياً.',
  }) async {
    try {
      await action();
    } catch (error) {
      // Keep offline reels quiet while Firestore is temporarily unavailable.
      if (_isTransientFirestoreError(error) || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _like() => _runInteraction(
        () => widget.service.toggleLike(widget.id),
        message: 'تعذر الإعجاب حالياً.',
      );

  Future<void> _save(bool saved) => _runInteraction(
        () => widget.service.toggleSave('socialReels', widget.id, saved),
        message: 'تعذر حفظ الريل حالياً.',
      );

  Future<void> _follow(String author, bool following) => _runInteraction(
        () => widget.service.toggleFollow(author, following),
        message: 'تعذر تحديث المتابعة حالياً.',
      );

  Future<void> _share() => _runInteraction(
        () => widget.service.shareReel(widget.id),
        message: 'تعذر مشاركة الريل حالياً.',
      );

  Future<void> _doubleLike() async {
    setState(() => _showHeart = true);
    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _showHeart = false);
    });
    if (!_liked) await _like();
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    final caption = widget.data['caption']?.toString() ?? '';
    final author = widget.data['authorId']?.toString() ?? 'مستخدم Memo';
    final published = widget.data['isPublished'] != false;

    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: _togglePlay,
            onDoubleTap: _doubleLike,
            onLongPress: () => showReelEditDialog(
              context: context,
              service: widget.service,
              id: widget.id,
              data: widget.data,
            ),
            child: player != null && player.value.isInitialized
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: player.value.size.width,
                      height: player.value.size.height,
                      child: VideoPlayer(player),
                    ),
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
          if (!published)
            const Center(
              child: Chip(label: Text('هذا الريل مخفي')),
            ),
          if (_showHeart)
            const Center(
              child: Icon(Icons.favorite_rounded, color: Colors.white, size: 104),
            ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 10,
            left: 14,
            right: 14,
            child: player != null && player.value.isInitialized
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: ValueListenableBuilder(
                      valueListenable: player,
                      builder: (_, value, __) => LinearProgressIndicator(
                        value: value.duration.inMilliseconds == 0
                            ? 0
                            : value.position.inMilliseconds / value.duration.inMilliseconds,
                        minHeight: 3,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Positioned(
            right: 12,
            bottom: MediaQuery.paddingOf(context).bottom + 116,
            child: StreamBuilder(
              stream: widget.service.watchLike('socialReels', widget.id),
              builder: (context, likeSnap) {
                final liked = likeSnap.data?.exists == true;
                return StreamBuilder(
                  stream: widget.service.watchSaved(widget.id),
                  builder: (context, saveSnap) {
                    final saved = saveSnap.data?.exists == true;
                    return StreamBuilder(
                      stream: author.isEmpty ? null : widget.service.watchFollowing(author),
                      builder: (context, followSnap) {
                        final following = followSnap.data?.exists == true;
                        return StreamBuilder<int>(
                          stream: widget.service.watchLikesCount(widget.id),
                          initialData: (widget.data['likesCount'] as num?)?.toInt() ?? 0,
                          builder: (context, countSnap) {
                            final data = {...widget.data, 'likesCount': countSnap.data ?? 0};
                            return ReelActions(
                              service: widget.service,
                              id: widget.id,
                              data: data,
                              liked: liked,
                              saved: saved,
                              following: following,
                              onLike: _like,
                              onComment: widget.data['commentsEnabled'] == false
                                  ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('التعليقات متوقفة لهذا الريل.')))
                                  : () => showCommentSheet(context, widget.service, widget.id),
                              onShare: _share,
                              onSave: () => _save(saved),
                              onFollow: author.isEmpty ? null : () => _follow(author, following),
                              onMore: () => showReelEditDialog(
                                context: context,
                                service: widget.service,
                                id: widget.id,
                                data: widget.data,
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          Positioned(
            left: 16,
            right: 82,
            bottom: MediaQuery.paddingOf(context).bottom + 24,
            child: ReelCaption(
              author: author,
              caption: caption,
              musicTitle: widget.data['musicTitle']?.toString() ?? '',
            ),
          ),
        ],
      ),
    );
  }
}
