import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:memochat/features/chat/presentation/widgets/chat_location_picker.dart';
import 'package:memochat/core/theme/app_colors.dart';
import 'package:memochat/features/chat/models/message_model.dart';
import 'package:memochat/features/chat/models/chat_model.dart';
import 'package:memochat/features/chat/models/status_model.dart';
import 'package:memochat/features/chat/services/chat_media_transfer_service.dart';
import 'package:memochat/features/chat/services/chat_reply_context.dart';
import 'package:memochat/features/chat/services/chat_service.dart';
import 'package:memochat/features/chat/services/toast_service.dart';
import 'package:memochat/features/chat/services/notification_service.dart';
import 'package:memochat/features/chat/services/status_service.dart';
import 'package:memochat/features/chat/presentation/story_viewer_screen.dart';
import 'package:memochat/features/chat/presentation/call_screen.dart';
import 'package:memochat/features/chat/presentation/message_search_screen.dart';
import 'package:memochat/features/chat/presentation/starred_messages_screen.dart';
import 'package:memochat/features/chat/presentation/group_info_screen.dart';
import 'package:memochat/features/chat/presentation/widgets/chat_background.dart';
import 'package:memochat/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:memochat/features/chat/presentation/widgets/media_upload_status_widget.dart';
import 'package:memochat/features/chat/presentation/widgets/message_bubble.dart';
import 'package:memochat/core/services/chat_preferences_service.dart';
import 'package:memochat/features/chat/presentation/chat_settings_screen.dart';

class ChatRoomScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserImage;
  final bool isGroup;
  final String? groupImage;
  final String? lastMessage;
  const ChatRoomScreen(
      {super.key,
      required this.chatId,
      required this.otherUserId,
      required this.otherUserName,
      this.otherUserImage,
      this.isGroup = false,
      this.groupImage,
      this.lastMessage});
  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  const _SwipeToReply({required this.child, required this.onReply});

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply> {
  static const double _triggerDistance = 64;
  double _dx = 0;

  void _reset() {
    if (mounted) setState(() => _dx = 0);
  }

  @override
  Widget build(BuildContext context) {
    final distance = _dx.abs();
    final progress = (distance / _triggerDistance).clamp(0.0, 1.0);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final iconAlignment = _dx >= 0
        ? AlignmentDirectional.centerStart
        : AlignmentDirectional.centerEnd;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        PositionedDirectional(
          start: isRtl ? null : 4,
          end: isRtl ? 4 : null,
          top: 0,
          bottom: 0,
          child: Align(
            alignment: iconAlignment,
            child: Opacity(
              opacity: progress,
              child: Transform.scale(
                scale: .75 + (.25 * progress),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(.12),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.reply_rounded,
                        size: 18, color: AppColors.primary),
                  ),
                ),
              ),
            ),
          ),
        ),
        Transform.translate(
          offset: Offset(_dx, 0),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: (details) {
              final next = (_dx + details.delta.dx).clamp(-96.0, 96.0);
              setState(() => _dx = next);
            },
            onHorizontalDragEnd: (_) {
              if (_dx.abs() >= _triggerDistance) {
                widget.onReply();
              }
              _reset();
            },
            onHorizontalDragCancel: _reset,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) {
    final value = name.trim();
    final initial = value.isEmpty ? 'م' : value.characters.first;
    return Container(
      color: AppColors.primary.withOpacity(.12),
      alignment: Alignment.center,
      child: Text(initial, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
    );
  }
}

class _ChatRoomScreenState extends State<ChatRoomScreen> with WidgetsBindingObserver {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _chat = ChatService();
  final _statusService = StatusService();
  StreamSubscription<MessagePaginationResult>? _messagesSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _chatSub;
  Timer? _messageStreamRetry;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  Timer? _pendingRefreshTimer;
  Timer? _typingClearTimer;
  Timer? _roomLoadTimer;
  bool _otherTyping = false;
  List<MessageModel> _messages = [];
  final List<Map<String, dynamic>> _localMedia = [];
  final Set<String> _knownMessageIds = <String>{};
  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};
  final ScrollController _scrollController = ScrollController();
  bool _showNewMessages = false;
  bool _loadingMoreMessages = false;
  DocumentSnapshot<Object?>? _oldestMessageDocument;
  bool _hasMoreMessages = false;
  final List<MessageModel> _olderMessages = <MessageModel>[];
  Set<String> _newMessageIds = <String>{};
  bool _hasInitialMessageSnapshot = false;
  bool _loading = true;
  String? _loadError;
  bool _online = false;
  bool get _selectionMode => _selectedMessageIds.isNotEmpty;
  DateTime? _lastSeen;
  bool _muted = false;
  bool _pinned = false;
  bool _starredLoading = false;
  final Set<String> _selectedMessageIds = <String>{};
  String _wallpaper = 'default';
  double _fontSize = 14.0;
  final _chatPrefs = ChatPreferencesService();
  MessageModel? _replyingTo;
  CollectionReference<Map<String, dynamic>> get _messagesRef =>
      _firestore.collection('chats').doc(widget.chatId).collection('messages');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onChatScroll);
    _initializeRoom();
    _loadChatPreferences();
    _loadPendingMedia();
    
    unawaited(NotificationService().cancelChatNotifications(widget.chatId));
    _markRead();
  }

  Future<void> _loadChatPreferences() async {
    try {
      final wallpaper = await _chatPrefs.getWallpaper(widget.chatId);
      final fontSize = await _chatPrefs.getFontSize(widget.chatId);
      if (!mounted) return;
      setState(() {
        _wallpaper = wallpaper ?? 'default';
        _fontSize = fontSize ?? 14.0;
      });
    } catch (e) {
      debugPrint('chat preferences load failed: $e');
    }
  }

  Future<void> _openChatSettings() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatSettingsScreen(chatId: widget.chatId)));
    await _loadChatPreferences();
  }

  Future<void> _setTyping(bool typing) async {
    _typingClearTimer?.cancel();
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty || widget.chatId.isEmpty) return;
    try {
      await _firestore.collection('chats').doc(widget.chatId).set({
        'typing.$uid': typing,
        'typingUpdatedAt.$uid': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (typing) {
        _typingClearTimer = Timer(const Duration(seconds: 4), () => unawaited(_setTyping(false)));
      }
    } catch (e) {
      debugPrint('typing update failed: $e');
    }
  }

  Future<void> _loadPendingMedia() async {
    try {
      final jobs =
          await ChatMediaTransferService.instance.pendingForChat(widget.chatId);
      if (!mounted) return;
      final pending = jobs.map(_pendingMap).toList();
      // Keep optimistic media visible until its Firestore message is observed.
      // The outbox can become sent before the messages listener receives the
      // new snapshot; clearing it here makes media disappear and reappear.
      final pendingIds = pending
          .map((m) => m['outboxId']?.toString())
          .whereType<String>()
          .toSet();
      final retained = _localMedia.where((m) {
        final id = m['outboxId']?.toString();
        return id != null && !pendingIds.contains(id);
      }).toList();
      setState(() {
        _localMedia
          ..clear()
          ..addAll(retained)
          ..addAll(pending);
      });
      _pendingRefreshTimer?.cancel();
      if (pending.isNotEmpty) {
        _pendingRefreshTimer = Timer.periodic(
          const Duration(milliseconds: 800),
          (_) async {
            if (!mounted) return;
            final jobs =
                await ChatMediaTransferService.instance.pendingForChat(widget.chatId);
            if (!mounted) return;
            if (jobs.isEmpty) {
              _pendingRefreshTimer?.cancel();
              _pendingRefreshTimer = null;
              await _loadPendingMedia();
            } else {
              await _loadPendingMedia();
            }
          },
        );
      }
    } catch (e) {
      debugPrint('pending media load: $e');
    }
  }

  Map<String, dynamic> _pendingMap(Map<String, dynamic> job) {
    final type = job['type']?.toString() ?? 'file';
    final local = job['local_path']?.toString() ?? '';
    final status = job['status']?.toString() ?? 'queued';
    final progress = (job['progress'] as num?)?.toDouble() ?? 0.0;
    final uploadStatus = status == 'retry'
        ? 'failed'
        : status == 'queued'
            ? 'pending'
            : 'uploading';
    return {
      'id': job['id'],
      'chatId': widget.chatId,
      'senderId': _auth.currentUser?.uid ?? 'local',
      'senderName': _auth.currentUser?.displayName ?? 'مستخدم',
      'type': type,
      'text': job['preview']?.toString() ?? 'مرفق',
      'imageUrl': type == 'image' ? local : null,
      'videoUrl': type == 'video' ? local : null,
      'audioUrl': type == 'audio' ? local : null,
      'fileUrl': type == 'file' ? local : null,
      'fileName': job['file_name'],
      'fileSize': job['file_size'],
      'fileMimeType': job['mime_type'],
      'audioDuration': job['audio_duration'],
      'isLocal': true,
      'isSending': status != 'retry',
      'isUploading':
          status == 'uploading' || status == 'queued' || status == 'retry',
      'hasError': status == 'retry',
      'uploadStatus': uploadStatus,
      'uploadProgress': progress,
      'outboxId': job['id'],
      'timestamp': job['created_at'] ?? DateTime.now().toIso8601String(),
      'onRetry': () async {
        await ChatMediaTransferService.instance.retry(job['id'].toString());
        if (mounted) await _loadPendingMedia();
      },
      'onCancel': () async {
        await ChatMediaTransferService.instance.cancel(job['id'].toString());
        if (mounted) await _loadPendingMedia();
      },
    };
  }

  void _addLocalMedia(Map<String, dynamic> media) {
    if (!mounted) return;
    setState(() {
      _localMedia.removeWhere((m) => m['outboxId'] == media['outboxId']);
      _localMedia.add(media);
    });
    unawaited(_loadPendingMedia());
  }

  bool _hiddenForCurrentUser(Map<String, dynamic> data) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    final deletedFor = data['deletedFor'];
    return deletedFor is Map && deletedFor[uid] == true;
  }

  Future<void> _initializeRoom() async {
    _roomLoadTimer?.cancel();
    _messageStreamRetry?.cancel();
    _roomLoadTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted || !_loading) return;
      setState(() {
        _loading = false;
        _loadError = 'استغرق تجهيز المحادثة وقتاً أطول من المتوقع. تحقق من اتصال Firebase ثم أعد المحاولة.';
      });
    });
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      if (mounted) setState(() { _loading = false; _loadError = 'يجب تسجيل الدخول لفتح المحادثة.'; });
      return;
    }
    if (widget.chatId.trim().isEmpty || widget.otherUserId.trim().isEmpty || widget.otherUserId == uid) {
      if (mounted) setState(() { _loading = false; _loadError = 'بيانات المحادثة غير صالحة.'; });
      return;
    }
    try {
      final ref = _firestore.collection('chats').doc(widget.chatId);
      DocumentSnapshot<Map<String, dynamic>>? snapshot;
      try {
        snapshot = await ref.get();
      } on FirebaseException catch (e) {
        // A stale route can point at a document the current rules reject.
        // Do not strand the user on an error screen; resolve the canonical DM.
        debugPrint('chat document read failed: ${e.code}');
      }
      if (snapshot?.exists == true) {
        final data = snapshot!.data() ?? <String, dynamic>{};
        final participants = (data['participants'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
        if (!participants.contains(uid)) {
          if (mounted) setState(() { _loading = false; _loadError = 'لا تملك صلاحية الوصول إلى هذه المحادثة.'; });
          return;
        }
        _listen();
        return;
      }

      // Some legacy entry points can provide a stale/in-memory conversation id.
      // Resolve the stable direct-chat document instead of trusting the stale id.
      final newChatId = await _chat.createChat(
        userId: widget.otherUserId,
        userName: widget.otherUserName.trim().isEmpty ? 'مستخدم' : widget.otherUserName.trim(),
        currentUserName: _auth.currentUser?.displayName?.trim().isNotEmpty == true
            ? _auth.currentUser!.displayName!.trim()
            : 'مستخدم MemoChat',
        userImage: widget.otherUserImage ?? widget.groupImage,
        currentUserImage: _auth.currentUser?.photoURL,
      );
      if (!mounted) return;
      if (newChatId != widget.chatId) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => ChatRoomScreen(
            chatId: newChatId,
            otherUserId: widget.otherUserId,
            otherUserName: widget.otherUserName,
            otherUserImage: widget.otherUserImage,
            isGroup: widget.isGroup,
            groupImage: widget.groupImage,
            lastMessage: widget.lastMessage,
          ),
        ));
        return;
      }
      _listen();
    } catch (e) {
      debugPrint('chat room initialization failed: $e');
      if (mounted) setState(() { _loading = false; _loadError = 'تعذر تجهيز المحادثة حالياً. تحقق من الاتصال ثم حاول مرة أخرى.'; });
    }
  }

  void _listen() {
    _roomLoadTimer?.cancel();
    _chatSub = _firestore
        .collection('chats')
        .doc(widget.chatId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      if (!snapshot.exists) {
        setState(() { _loading = false; _loadError ??= 'المحادثة غير موجودة.'; });
        return;
      }
      final data = snapshot.data() ?? <String, dynamic>{};
      final uid = _auth.currentUser?.uid;
      final mutedFor = data['mutedFor'];
      final pinnedFor = data['pinnedFor'];
      final typing = data['typing'];
      final otherId = widget.otherUserId;
      final otherTyping = typing is Map && typing[otherId] == true;
      if (mounted && _otherTyping != otherTyping)
        setState(() => _otherTyping = otherTyping);
      setState(() {
        _muted = mutedFor is Map && mutedFor[uid] == true
            ? true
            : data['isMuted'] == true && mutedFor is! Map;
        _pinned = pinnedFor is Map && pinnedFor[uid] == true
            ? true
            : data['isPinned'] == true && pinnedFor is! Map;
      });
    });
    _userSub = _firestore
        .collection('users')
        .doc(widget.otherUserId)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        final data = snapshot.data() ?? <String, dynamic>{};
        final rawLastSeen = data['lastSeen'];
        final lastSeen = rawLastSeen is Timestamp ? rawLastSeen.toDate() : (rawLastSeen is DateTime ? rawLastSeen : null);
        setState(() { _online = data['isOnline'] == true; _lastSeen = lastSeen; });
      }
    });
    _messagesSub?.cancel();
    _messagesSub = _chat
        .streamMessages(widget.chatId, limit: 100)
        .listen((page) {
      if (!mounted) return;
      _roomLoadTimer?.cancel();
      _oldestMessageDocument = page.lastDocument ?? _oldestMessageDocument;
      _hasMoreMessages = page.hasMore;
      final liveMessages = <MessageModel>[];
      for (final message in page.messages) {
        try {
          if (!_hiddenForCurrentUser(message.toFirestore())) {
            liveMessages.add(message);
          }
        } catch (error, stackTrace) {
          debugPrint('Skipping malformed message ${message.id}: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }
      final liveIds = liveMessages.map((m) => m.id).toSet();
      final messages = <MessageModel>[
        ...liveMessages,
        ..._olderMessages.where((m) => !liveIds.contains(m.id)),
      ];
      messages.sort((a, b) =>
          (b.timestamp ?? Timestamp(0, 0)).compareTo(a.timestamp ?? Timestamp(0, 0)));

      final remoteIds = messages.map((m) => m.id).toSet();
      final remoteMediaKeys = messages
          .map((m) => m.idempotencyKey)
          .whereType<String>()
          .where((key) => key.startsWith('media_'))
          .map((key) => key.substring('media_'.length))
          .toSet();
      final newIds = _hasInitialMessageSnapshot
          ? remoteIds.difference(_knownMessageIds)
          : <String>{};
      _knownMessageIds
        ..clear()
        ..addAll(remoteIds);
      _newMessageIds = newIds;
      _hasInitialMessageSnapshot = true;
      final wasAwayFromLatest = _scrollController.hasClients &&
          _scrollController.position.pixels > 140;
      setState(() {
        _messages = messages;
        _localMedia.removeWhere((m) {
          final outboxId = m['outboxId']?.toString();
          return remoteIds.contains(m['id']) ||
              (outboxId != null && remoteMediaKeys.contains(outboxId));
        });
        _loading = false;
        if (!wasAwayFromLatest) {
          _showNewMessages = false;
        } else if (newIds.isNotEmpty) {
          _showNewMessages = true;
        }
      });
      if (newIds.isNotEmpty && !wasAwayFromLatest) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
      }
      unawaited(_markDeliveryAndRead());
      unawaited(_loadPendingMedia());
    }, onError: (error) {
      debugPrint('chat messages stream: $error');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = null;
      });
      _messageStreamRetry?.cancel();
      _messageStreamRetry = Timer(const Duration(seconds: 2), () {
        if (mounted) _listen();
      });
    });

