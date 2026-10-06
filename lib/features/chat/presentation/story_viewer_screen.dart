import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:memochat/core/constants/app_colors.dart';
import 'package:memochat/features/chat/models/status_model.dart';
import 'package:memochat/features/chat/services/status_service.dart';

class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.status,
    this.initialIndex = 0,
  });

  final UserStatusModel status;
  final int initialIndex;

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _progressController;
  final StatusService _statusService = StatusService();
  final TextEditingController _replyController = TextEditingController();

  late int _currentIndex;
  bool _isPaused = false;
  bool _sendingReply = false;
  final Set<int> _readyStories = <int>{};
  bool _progressStarted = false;
  bool _viewMarked = false;

  Future<void> _markViewedWhenReady() async {
    if (_viewMarked) return;
    _viewMarked = true;
    try {
      await _statusService.markViewed(widget.status);
    } catch (_) {
      // Viewing the story must never block or delay the viewer UI.
      _viewMarked = false;
    }
  }

  StoryItem get _currentStory => widget.status.stories[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.status.stories.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _progressController = AnimationController(
      vsync: this,
      duration: _currentStory.duration,
    )..addStatusListener(_onProgressStatus);
    // Do not mark the story as viewed here. A view is recorded only after
    // the first story has actually produced visible content.
    _progressController.forward();
  }

  void _onProgressStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) _goToNext();
  }

  void _resetProgress() {
    _progressController
      ..stop()
      ..duration = _currentStory.duration
      ..reset();
    _progressStarted = false;
    if (_readyStories.contains(_currentIndex) && !_isPaused) {
      _startProgress();
    }
  }

  void _startProgress() {
    if (!mounted || _isPaused || _progressStarted) return;
    _progressStarted = true;
    _progressController
      ..duration = _currentStory.duration
      ..forward();
    _statusService.markViewed(widget.status);
  }

  void _onStoryReady(int index) {
    if (!mounted || index != _currentIndex) return;
    if (_readyStories.add(index)) {
      setState(() {});
    }
    _startProgress();
  }

  void _goToNext() {
    if (_currentIndex < widget.status.stories.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _goToPrevious() {
    if (_currentIndex == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
    if (_isPaused) {
      _progressController.stop();
    } else {
      _progressController.forward();
    }
  }

  void _setPaused(bool paused) {
    if (_isPaused == paused) return;
    setState(() => _isPaused = paused);
    if (paused) {
      _progressController.stop();
    } else {
      _progressController.forward();
    }
  }

  Future<void> _react(String emoji) async {
    await _statusService.addReaction(status: widget.status, emoji: emoji);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم إرسال $emoji'), duration: const Duration(milliseconds: 700)),
      );
    }
  }

  Future<void> _sendReply() async {
    if (_sendingReply) return;
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sendingReply = true);
    try {
      await _statusService.addReply(status: widget.status, text: text);
      _replyController.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال الرد'), duration: Duration(milliseconds: 700)),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingReply = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.status.stories.isEmpty) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          final width = MediaQuery.sizeOf(context).width;
          final x = details.globalPosition.dx;
          if (x < width / 3) {
            _goToPrevious();
          } else if (x > width * 2 / 3) {
            _goToNext();
          } else {
            _togglePause();
          }
        },
        onLongPressStart: (_) => _setPaused(true),
        onLongPressEnd: (_) => _setPaused(false),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.status.stories.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
                _resetProgress();
              },
              itemBuilder: (_, index) => _StoryContent(
                story: widget.status.stories[index],
                paused: _isPaused,
                onReady: index == _currentIndex ? _markViewedWhenReady : null,
              ),
            ),
            _buildProgressBars(),
            _buildHeader(),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBars() {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 8,
      left: 8,
      right: 8,
      child: Row(
        children: List.generate(widget.status.stories.length, (index) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedBuilder(
                animation: _progressController,
                builder: (_, __) {
                  final value = index < _currentIndex
                      ? 1.0
                      : index == _currentIndex
                          ? _progressController.value
                          : 0.0;
                  return LinearProgressIndicator(
                    value: value,
                    minHeight: 3,
                    backgroundColor: Colors.white.withOpacity(.28),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  );
                },
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 22,
      left: 16,
      right: 8,
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: AppColors.primary,
            backgroundImage: widget.status.userImage?.isNotEmpty == true
                ? NetworkImage(widget.status.userImage!)
                : null,
            child: widget.status.userImage?.isNotEmpty == true
                ? null
                : Text(widget.status.userName.characters.first, style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.status.userName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                Text(
                  _relativeTime(widget.status.createdAt),
                  style: TextStyle(color: Colors.white.withOpacity(.72), fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Positioned(
      left: 12,
      right: 12,
      bottom: MediaQuery.paddingOf(context).bottom + 14,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.16),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withOpacity(.28)),
                  ),
                  child: TextField(
                    controller: _replyController,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'رد سريع...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(.7)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendReply(),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: _sendingReply ? null : _sendReply,
                icon: const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['❤️', '😂', '😮', '😢', '👏'].map((emoji) {
              return GestureDetector(
                onTap: () => _react(emoji),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.18),
                    shape: BoxShape.circle,
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 23)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime date) {
    final minutes = DateTime.now().difference(date).inMinutes;
    if (minutes < 1) return 'الآن';
    if (minutes < 60) return 'منذ $minutes د';
    final hours = minutes ~/ 60;
    if (hours < 24) return 'منذ $hours س';
    return 'منذ يوم';
  }
}

class _StoryContent extends StatefulWidget {
  const _StoryContent({required this.story, required this.paused, this.onReady});

  final StoryItem story;
  final bool paused;
  final VoidCallback? onReady;

  @override
  State<_StoryContent> createState() => _StoryContentState();
}

class _StoryContentState extends State<_StoryContent> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    if (widget.story.type != 'video' || widget.story.url.isEmpty) return;
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.story.url));
    _controller = controller;
    await controller.initialize();
    controller.setLooping(true);
    if (mounted) widget.onReady?.call();
    if (!widget.paused) controller.play();
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant _StoryContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller != null) {
      if (widget.paused) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.story.type == 'image' && widget.story.url.isNotEmpty) {
      return Image.network(
        widget.story.url,
        fit: BoxFit.contain,
        frameBuilder: (_, child, frame, wasSynchronouslyLoaded) {
          if (frame != null || wasSynchronouslyLoaded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) widget.onReady?.call();
            });
          }
          return child;
        },
        errorBuilder: (_, __, ___) => _textContent('تعذر تحميل الصورة'),
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : Stack(
                alignment: Alignment.center,
                children: [
                  const ColoredBox(color: Colors.black),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 12),
                      Text(
                        'جاري تحميل الحالة…',
                        style: TextStyle(color: Colors.white.withOpacity(.8)),
                      ),
                    ],
                  ),
                ],
              ),
      );
    }

    if (widget.story.type == 'video') {
      final controller = _controller;
      if (controller == null || !controller.value.isInitialized) {
        return const Center(child: CircularProgressIndicator(color: Colors.white));
      }
      return Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReady?.call();
    });
    return _textContent(widget.story.text ?? '');
  }

  List<Color> _textColors(String text) {
    const palettes = <List<Color>>[
      [Color(0xFF0A8F83), Color(0xFF14532D)],
      [Color(0xFF2563EB), Color(0xFF4C1D95)],
      [Color(0xFFDB2777), Color(0xFF7C2D12)],
      [Color(0xFF7C3AED), Color(0xFF1E3A8A)],
      [Color(0xFFEA580C), Color(0xFF9A3412)],
      [Color(0xFF0891B2), Color(0xFF164E63)],
    ];
    final hash = text.codeUnits.fold<int>(0, (sum, code) => sum + code);
    return palettes[hash.abs() % palettes.length];
  }

  Widget _textContent(String text) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _textColors(text),
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(36),
      child: Text(
        text,
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w800),
      ),
    );
  }
}
