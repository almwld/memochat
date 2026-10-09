import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
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
import 'package:memochat/features/chat/services/message_delivery_service.dart';
import 'package:memochat/features/chat/services/status_service.dart';
import 'package:memochat/features/chat/presentation/story_viewer_screen.dart';
import 'package:memochat/features/chat/presentation/message_search_screen.dart';
import 'package:memochat/features/chat/presentation/starred_messages_screen.dart';
import 'package:memochat/features/chat/presentation/group_info_screen.dart';
import 'package:memochat/features/chat/presentation/widgets/chat_background.dart';
import 'package:memochat/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:memochat/features/chat/presentation/widgets/media_upload_status_widget.dart';
import 'package:memochat/features/chat/presentation/widgets/message_bubble.dart';
import 'package:memochat/core/services/chat_preferences_service.dart';
import 'package:memochat/features/chat/presentation/chat_settings_screen.dart';
import 'package:memochat/features/chat/presentation/account_info_screen.dart';
import 'package:memochat/features/chat/presentation/call_screen.dart';

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
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  Timer? _pendingRefreshTimer;
  int _pendingMediaLoadGeneration = 0;
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
  bool _initializingRoom = false;
  bool _online = false;
  bool get _selectionMode => _selectedMessageIds.isNotEmpty;
  DateTime? _lastSeen;
  bool _muted = false;
  bool _pinned = false;
  bool _starredLoading = false;
  final Set<String> _selectedMessageIds = <String>{};
  late String _activeChatId;
  String get _chatId => _activeChatId;
  String _wallpaper = 'default';
  double _fontSize = 14.0;
  final _chatPrefs = ChatPreferencesService();
  MessageModel? _replyingTo;
  CollectionReference<Map<String, dynamic>> get _messagesRef =>
      _firestore.collection('chats').doc(_chatId).collection('messages');

  @override
  void initState() {
    super.initState();
    _activeChatId = widget.chatId;
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onChatScroll);
    _initializeRoom();
    _loadChatPreferences();
    _loadPendingMedia();
    
    unawaited(NotificationService().cancelChatNotifications(_chatId));
    _markRead();
  }

  Future<void> _loadChatPreferences() async {
    try {
      final wallpaper = await _chatPrefs.getWallpaper(_chatId);
      final fontSize = await _chatPrefs.getFontSize(_chatId);
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
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatSettingsScreen(chatId: _chatId)));
    await _loadChatPreferences();
  }

  Future<void> _setTyping(bool typing) async {
    _typingClearTimer?.cancel();
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty || _chatId.isEmpty) return;
    try {
      await _firestore.collection('chats').doc(_chatId).set({
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
    final generation = ++_pendingMediaLoadGeneration;
    try {
      final jobs =
          await ChatMediaTransferService.instance.pendingForChat(_chatId);
      if (!mounted || generation != _pendingMediaLoadGeneration) return;

      // A pending query can finish after the Firestore listener has already
      // observed the canonical message. Reconcile against the latest snapshot
      // *after* the await so a stale outbox result cannot resurrect a retry
      // bubble beside the successfully published message.
      final remoteIds = _messages.map((m) => m.id).toSet();
      final remoteMediaKeys = _messages
          .map((m) => m.idempotencyKey)
          .whereType<String>()
          .where((key) => key.startsWith('media_'))
          .map((key) => key.substring('media_'.length))
          .toSet();
      bool alreadyPublished(Map<String, dynamic> media) {
        final id = media['id']?.toString();
        final outboxId = media['outboxId']?.toString();
        return (id != null && remoteIds.contains(id)) ||
            (outboxId != null && remoteMediaKeys.contains(outboxId));
      }

      final pending = jobs
          .map(_pendingMap)
          .where((media) => !alreadyPublished(media))
          .toList();
      final pendingIds = pending
          .map((m) => m['outboxId']?.toString())
          .whereType<String>()
          .toSet();
      final retained = _localMedia.where((media) {
        final id = media['outboxId']?.toString();
        return !alreadyPublished(media) &&
            id != null &&
            !pendingIds.contains(id);
      }).toList();

      setState(() {
        _localMedia
          ..clear()
          ..addAll(retained)
          ..addAll(pending);
      });
      _pendingRefreshTimer?.cancel();
      _pendingRefreshTimer = null;
      if (pending.isNotEmpty) {
        _pendingRefreshTimer = Timer.periodic(
          const Duration(milliseconds: 800),
          (_) => unawaited(_loadPendingMedia()),
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
      'chatId': _chatId,
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
    if (_initializingRoom) return;
    _initializingRoom = true;
    try {
      await _initializeRoomInternal();
    } finally {
      _initializingRoom = false;
    }
  }

  Future<void> _initializeRoomInternal() async {
    _roomLoadTimer?.cancel();
    _roomLoadTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted || !_loading) return;
      setState(() {
        _loading = false;
        _loadError = null;
      });
    });
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      if (mounted) setState(() { _loading = false; _loadError = 'يجب تسجيل الدخول لفتح المحادثة.'; });
      return;
    }
    if (_chatId.trim().isEmpty || (!widget.isGroup && (widget.otherUserId.trim().isEmpty || widget.otherUserId == uid))) {
      if (mounted) setState(() { _loading = false; _loadError = 'بيانات المحادثة غير صالحة.'; });
      return;
    }
    try {
      final ref = _firestore.collection('chats').doc(_chatId);
      // Start rendering the cached/live stream while the authorization read
      // is in flight. This removes the blank bubble-room gap on slow networks.
      final listenerFuture = _listen();
      DocumentSnapshot<Map<String, dynamic>>? snapshot;
      try {
        snapshot = await ref.get();
      } on FirebaseException catch (e) {
        debugPrint('chat document read failed: ${e.code}');
        // An unavailable backend must not prevent a valid room from opening.
        if (e.code == 'unavailable' ||
            e.code == 'deadline-exceeded' ||
            e.code == 'failed-precondition') {
          unawaited(_listen());
          return;
        }
      }
      if (snapshot?.exists == true) {
        final data = snapshot!.data() ?? <String, dynamic>{};
        final participants = (data['participants'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
        if (!participants.contains(uid)) {
          if (mounted) setState(() { _loading = false; _loadError = 'لا تملك صلاحية الوصول إلى هذه المحادثة.'; });
          return;
        }
        await listenerFuture;
        return;
      }

      // Group rooms must never fall through to direct-chat creation. A group
      // route is valid as soon as its document exists and contains the user.
      if (widget.isGroup) {
        if (mounted) setState(() { _loading = false; _loadError = 'المجموعة غير موجودة أو لم تعد متاحة.'; });
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
      if (newChatId != _chatId) {
        // Correct the stale room id in-place. Creating another
        // ChatRoomScreen here causes stacked/repeated room routes.
        _activeChatId = newChatId;
        _knownMessageIds.clear();
        _newMessageIds = <String>{};
        _hasInitialMessageSnapshot = false;
        _olderMessages.clear();
        _hasMoreMessages = false;
        _oldestMessageDocument = null;
        _loadError = null;
        _loading = true;
        await _listen();
        return;
      }
      await listenerFuture;
    } on FirebaseException catch (e) {
      debugPrint('chat room initialization Firebase failure: ${e.code}');
      if (!mounted) return;
      if (e.code == 'permission-denied') {
        setState(() { _loading = false; _loadError = 'لا تملك صلاحية الوصول إلى هذه المحادثة.'; });
      } else {
        setState(() { _loading = false; _loadError = null; });
        unawaited(_listen());
      }
    } catch (e) {
      debugPrint('chat room initialization failed: $e');
      if (mounted) setState(() { _loading = false; _loadError = null; });
      if (mounted) unawaited(_listen());
    }
  }

  Future<void> _listen() async {
    _roomLoadTimer?.cancel();
    // Retries replace subscriptions; never accumulate duplicate listeners.
    await _chatSub?.cancel();
    _chatSub = null;
    await _userSub?.cancel();
    _userSub = null;
    _chatSub = _firestore
        .collection('chats')
        .doc(_chatId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      if (!snapshot.exists) {
        setState(() {
          _loading = false;
          _loadError ??= 'المحادثة غير موجودة.';
        });
        return;
      }
      final data = snapshot.data() ?? <String, dynamic>{};
      final uid = _auth.currentUser?.uid;
      final mutedFor = data['mutedFor'];
      final pinnedFor = data['pinnedFor'];
      final typing = data['typing'];
      final otherId = widget.otherUserId.trim();
      final otherTyping =
          !widget.isGroup && otherId.isNotEmpty && typing is Map && typing[otherId] == true;
      if (mounted && _otherTyping != otherTyping) {
        setState(() => _otherTyping = otherTyping);
      }
      setState(() {
        _loading = false;
        _loadError = null;
        _muted = mutedFor is Map && mutedFor[uid] == true
            ? true
            : data['isMuted'] == true && mutedFor is! Map;
        _pinned = pinnedFor is Map && pinnedFor[uid] == true
            ? true
            : data['isPinned'] == true && pinnedFor is! Map;
      });
    }, onError: (Object error, StackTrace stackTrace) {
      debugPrint('chat metadata stream failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = null;
      });
    });

    // Group rooms do not have a single "other user".
    if (!widget.isGroup && widget.otherUserId.trim().isNotEmpty) {
      _userSub = _firestore
          .collection('users')
          .doc(widget.otherUserId.trim())
          .snapshots()
          .listen((snapshot) {
        if (mounted) {
          final data = snapshot.data() ?? <String, dynamic>{};
          final rawLastSeen = data['lastSeen'];
          final lastSeen = rawLastSeen is Timestamp
              ? rawLastSeen.toDate()
              : (rawLastSeen is DateTime ? rawLastSeen : null);
          setState(() {
            _online = data['isOnline'] == true;
            _lastSeen = lastSeen;
          });
        }
      }, onError: (Object error, StackTrace stackTrace) {
        debugPrint('chat user stream failed: $error');
      });
    }

    await _messagesSub?.cancel();
    // The room consumes ChatService's canonical Firestore stream.
    // Encryption layers are intentionally suspended for this transport path.
    _messagesSub = _chat.streamMessages(_chatId, limit: 100).listen((page) {
      if (!mounted) return;
      _roomLoadTimer?.cancel();
      _oldestMessageDocument =
          page.lastDocument ?? _oldestMessageDocument;
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
      final messages = <MessageModel>[...liveMessages, ..._olderMessages.where((m) => !liveIds.contains(m.id))];
      messages.sort((a, b) => (b.timestamp ?? Timestamp(0, 0)).compareTo(a.timestamp ?? Timestamp(0, 0)));
      final remoteIds = messages.map((m) => m.id).toSet();
      final remoteMediaKeys = messages
          .map((m) => m.idempotencyKey)
          .whereType<String>()
          .where((key) => key.startsWith('media_'))
          .map((key) => key.substring('media_'.length))
          .toSet();
      final currentIds = remoteIds;
      final newIds = _hasInitialMessageSnapshot
          ? currentIds.difference(_knownMessageIds)
          : <String>{};
      _knownMessageIds
        ..clear()
        ..addAll(currentIds);
      _newMessageIds = newIds;
      _hasInitialMessageSnapshot = true;
      final wasAwayFromLatest = _scrollController.hasClients && _scrollController.position.pixels > 140;
      setState(() {
        // Optimistic and canonical text messages use the exact same Firestore
        // document ID, so the snapshot replaces the local bubble atomically.
        _messages = messages;
        _localMedia.removeWhere((m) {
          final outboxId = m['outboxId']?.toString();
          return remoteIds.contains(m['id']) ||
              (outboxId != null && remoteMediaKeys.contains(outboxId));
        });
        _loading = false;
        if (!wasAwayFromLatest) _showNewMessages = false;
        else if (newIds.isNotEmpty) _showNewMessages = true;
      });
      if (newIds.isNotEmpty && !wasAwayFromLatest) WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
      unawaited(_markDeliveryAndRead());
      unawaited(_loadPendingMedia());
    }, onError: (error) {
      debugPrint('chat messages stream: $error');
      if (!mounted) return;
      // Firestore snapshots reconnect themselves after transient network
      // failures. Do not rebuild the listener from inside its own error
      // callback: doing so can create a reconnect/rebuild loop.
      // Keep the last rendered messages visible.
      setState(() {
        _loading = false;
        _loadError = null;
      });
    });
  }

  DateTime _messageTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is num) {
      final n = value.toInt();
      return DateTime.fromMillisecondsSinceEpoch(
          n > 100000000000 ? n : n * 1000);
    }
    if (value is String)
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> _forwardMessage(MessageModel message) async {
    if (message.id.isEmpty) return;
    try {
      final chats = await _chat.streamChats(limit: 100).first;
      if (!mounted) return;
      final destinations = chats.where((chat) => chat.id != _chatId).toList();
      if (destinations.isEmpty) {
        ToastService.showInfo('لا توجد محادثات أخرى لإعادة التوجيه إليها.');
        return;
      }
      final selected = await showModalBottomSheet<ChatModel>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) {
          final query = ValueNotifier<String>('');
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .72,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 10),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text('إعادة توجيه إلى', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      onChanged: (value) => query.value = value.trim().toLowerCase(),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'ابحث عن محادثة...',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ValueListenableBuilder<String>(
                      valueListenable: query,
                      builder: (_, value, __) {
                        final filtered = destinations.where((chat) {
                          final name = chat.getDisplayName(_auth.currentUser?.uid ?? '');
                          return value.isEmpty || name.toLowerCase().contains(value);
                        }).toList();
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 4),
                          itemBuilder: (_, index) {
                            final chat = filtered[index];
                            final name = chat.getDisplayName(_auth.currentUser?.uid ?? '');
                            final photo = chat.getDisplayPhoto(_auth.currentUser?.uid ?? '');
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: photo.trim().isEmpty ? null : NetworkImage(photo.trim()),
                                child: photo.trim().isEmpty ? Text(name.isEmpty ? 'م' : name.characters.first) : null,
                              ),
                              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                              subtitle: chat.isGroup ? const Text('مجموعة') : null,
                              trailing: const Icon(Icons.arrow_back_rounded),
                              onTap: () => Navigator.pop(context, chat),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (selected == null || !mounted) return;
      await _chat.forwardMessage(
        sourceChatId: _chatId,
        messageId: message.id,
        destinationChatId: selected.id,
      );
      if (mounted) ToastService.showSuccess('تمت إعادة توجيه الرسالة');
    } catch (e) {
      if (mounted) ToastService.showError('تعذر إعادة توجيه الرسالة: $e');
    }
  }

  void _toggleMessageSelection(String id) {
    setState(() {
      if (_selectedMessageIds.contains(id)) {
        _selectedMessageIds.remove(id);
      } else {
        _selectedMessageIds.add(id);
      }
    });
  }

  List<MessageModel> _selectedModels() =>
      _messages.where((m) => _selectedMessageIds.contains(m.id)).toList();

  Future<void> _deleteSelectedMessages() async {
    for (final message in _selectedModels()) {
      try { await _chat.deleteMessage(_chatId, message.id); } catch (_) {}
    }
    if (mounted) setState(() => _selectedMessageIds.clear());
  }

  Future<void> _copySelectedMessages() async {
    final text = _selectedModels().map((m) => m.text?.trim()).whereType<String>().where((v) => v.isNotEmpty).join('\n');
    if (text.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) ToastService.showSuccess('تم نسخ الرسائل المحددة');
    }
    if (mounted) setState(() => _selectedMessageIds.clear());
  }

  Future<void> _starSelectedMessages() async {
    for (final message in _selectedModels()) {
      try { await _chat.starMessage(_chatId, message.id, true); } catch (_) {}
    }
    if (mounted) setState(() => _selectedMessageIds.clear());
  }

  void _clearSelection() => setState(() => _selectedMessageIds.clear());

  Future<void> _toggleMessageStar(MessageModel message) async {
    if (_starredLoading) return;
    setState(() => _starredLoading = true);
    try {
      await _chat.starMessage(_chatId, message.id, !message.isStarred);
      if (mounted) ToastService.showSuccess(message.isStarred ? 'أزيلت من المفضلة' : 'حُفظت في المفضلة');
    } catch (e) {
      if (mounted) ToastService.showError('تعذر حفظ الرسالة: $e');
    } finally {
      if (mounted) setState(() => _starredLoading = false);
    }
  }

  Future<void> _showStarredMessages() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => StarredMessagesScreen(chatId: _chatId)));
  }

  Future<void> _markDeliveryAndRead() async {
    try {
      await MessageDeliveryService.instance.acknowledgeDelivered(
        chatId: _chatId,
        messageIds: _messages.map((message) => message.id),
      );
    } catch (error) {
      debugPrint('message delivery acknowledgement failed: $error');
    }
    await _markRead();
  }

  Future<void> _markRead() async {
    try {
      await _chat.markAsRead(_chatId);
    } catch (error) {
      debugPrint('mark read: $error');
    }
  }

  String _lastSeenLabel() {
    final value = _lastSeen;
    if (value == null) return 'غير متصل';
    final now = DateTime.now();
    final diff = now.difference(value);
    if (diff.inMinutes < 1) return 'آخر ظهور منذ لحظات';
    if (diff.inMinutes < 60) return 'آخر ظهور منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'آخر ظهور منذ ${diff.inHours} س';
    if (diff.inDays < 7) return 'آخر ظهور منذ ${diff.inDays} يوم';
    return 'آخر ظهور ${value.day.toString().padLeft(2,'0')}/${value.month.toString().padLeft(2,'0')}';
  }

  Future<void> _call(bool video) async {
    final permissions = <Permission>[
      Permission.microphone,
      if (video) Permission.camera,
    ];
    final statuses = await permissions.request();
    final micGranted = statuses[Permission.microphone]?.isGranted == true;
    final cameraGranted = !video || statuses[Permission.camera]?.isGranted == true;
    if (!micGranted || !cameraGranted) {
      if (mounted) {
        ToastService.showError(
          video
              ? 'السماح بالكاميرا والميكروفون مطلوب لبدء المكالمة.'
              : 'السماح بالميكروفون مطلوب لبدء المكالمة.',
        );
      }
      return;
    }
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
        builder: (_) => CallScreen(
            chatId: _chatId,
            userName: widget.otherUserName,
            userId: widget.otherUserId,
            userImage: widget.otherUserImage ?? widget.groupImage,
            isVideo: video,
            isOutgoing: true)));
  }

  Future<void> _openGroupInfo() async {
    if (!widget.isGroup) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupInfoScreen(chatId: _chatId)));
  }

  Future<void> _profile() async {
    if (widget.otherUserId.trim().isEmpty) return;

    var displayName = widget.otherUserName.trim();
    var image = (widget.otherUserImage ?? widget.groupImage)?.trim() ?? '';

    try {
      final snapshot = await _firestore.collection('users').doc(widget.otherUserId).get();
      final data = snapshot.data() ?? <String, dynamic>{};
      final storedName = data['displayName']?.toString().trim();
      final profileName = data['name']?.toString().trim();
      if (storedName?.isNotEmpty == true) {
        displayName = storedName!;
      } else if (profileName?.isNotEmpty == true) {
        displayName = profileName!;
      }
      final storedImage = data['photoUrl']?.toString().trim();
      final authImage = data['photoURL']?.toString().trim();
      if (storedImage?.isNotEmpty == true) {
        image = storedImage!;
      } else if (authImage?.isNotEmpty == true) {
        image = authImage!;
      }
    } catch (e) {
      debugPrint('load contact profile failed: $e');
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: image.isNotEmpty ? NetworkImage(image) : null,
                child: image.isNotEmpty ? null : const Icon(Icons.person_rounded, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName.isEmpty ? 'مستخدم MemoChat' : displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'معلومات جهة الاتصال',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openOtherUserStatus(UserStatusModel status) async { if (!mounted || status.stories.isEmpty) return; await Navigator.push(context, MaterialPageRoute(builder: (_) => StoryViewerScreen(status: status))); }

  void _onChatScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels > 140 && !_showNewMessages && mounted) {
      setState(() => _showNewMessages = true);
    } else if (_scrollController.position.pixels <= 40 && _showNewMessages && mounted) {
      setState(() => _showNewMessages = false);
    }
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 180 &&
        !_loadingMoreMessages && _hasMoreMessages) {
      unawaited(_loadOlderMessages());
    }
  }

  Future<void> _jumpToMessage(String id) async {
    if (id.isEmpty) return;

    // First try the currently rendered timeline.
    final key = _messageKeys[id];
    final target = key?.currentContext;
    if (target != null) {
      await Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        alignment: .45,
      );
      return;
    }

    // A reply can point to an older message that is outside the current
    // pagination window. Load that exact Firestore document instead of
    // reporting that the message does not exist.
    try {
      final snap = await _firestore
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .doc(id)
          .get();

      if (!snap.exists || snap.data() == null) {
        if (mounted) ToastService.showError('تعذر العثور على الرسالة الأصلية.');
        return;
      }

      final loaded = MessageModel.fromFirestore(snap.id, snap.data()!);
      if (!mounted) return;

      setState(() {
        if (!_messages.any((m) => m.id == loaded.id)) {
          _messages = <MessageModel>[..._messages, loaded]
            ..sort((a, b) => (b.timestamp ?? b.clientTimestamp ?? Timestamp(0, 0))
                .compareTo(a.timestamp ?? a.clientTimestamp ?? Timestamp(0, 0)));
        }
        _knownMessageIds.add(loaded.id);
      });

      // The list is reversed; wait for the newly inserted target to be
      // laid out, then reveal it.
      await WidgetsBinding.instance.endOfFrame;
      final loadedKey = _messageKeys.putIfAbsent(id, GlobalKey.new);
      final loadedContext = loadedKey.currentContext;
      if (loadedContext != null) {
        await Scrollable.ensureVisible(
          loadedContext,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          alignment: .45,
        );
      } else if (mounted) {
        ToastService.showInfo('تم العثور على الرسالة الأصلية، مرر المحادثة للوصول إليها.');
      }
    } catch (e) {
      if (mounted) ToastService.showError('تعذر فتح الرسالة الأصلية.');
    }
  }

  void _scrollToLatest() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    if (mounted) setState(() => _showNewMessages = false);
  }

  void _optimisticallyAddTextMessage(
    String text, {
    Timestamp? clientTimestamp,
    String? replyToId,
    Map<String, dynamic>? replyPreview,
  }) {
    final value = text.trim();
    final uid = _auth.currentUser?.uid;
    if (!mounted || value.isEmpty || uid == null) return;

    final now = clientTimestamp ?? Timestamp.now();
    final optimisticId = 'msg_${now.microsecondsSinceEpoch}';

    setState(() {
      // Render the newly sent text immediately. The Firestore listener will
      // replace this optimistic item with the canonical server message.
      _messages = <MessageModel>[
        MessageModel(
          id: optimisticId,
          chatId: _chatId,
          senderId: uid,
          senderName: _auth.currentUser?.displayName ?? 'مستخدم',
          senderPhotoUrl: _auth.currentUser?.photoURL,
          text: value,
          type: MessageType.text,
          timestamp: now,
          clientTimestamp: now,
          isRead: false,
          isDelivered: false,
          status: MessageStatus.sending,
          replyToId: replyToId,
          replyPreview: replyPreview,
        ),
        ..._messages.where((message) => message.id != optimisticId),
      ];
      _knownMessageIds.add(optimisticId);
      _newMessageIds = <String>{optimisticId};
      _showNewMessages = false;
    });

    // The ListView is reversed, so offset 0 is the newest message.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _loadOlderMessages() async {
    if (_loadingMoreMessages || !_hasMoreMessages || _oldestMessageDocument == null) return;
    setState(() => _loadingMoreMessages = true);
    try {
      final page = await _chat.getMoreMessages(chatId: _chatId, limit: 30, startAfter: _oldestMessageDocument);
      if (!mounted) return;
      final existing = _messages.map((m) => m.id).toSet();
      final merged = <MessageModel>[..._messages];
      for (final m in page.messages) {
        if (!existing.contains(m.id)) merged.add(m);
      }
      merged.sort((a, b) => (b.timestamp ?? Timestamp(0, 0)).compareTo(a.timestamp ?? Timestamp(0, 0)));
      setState(() {
        final knownOlder = _olderMessages.map((m) => m.id).toSet();
        _olderMessages.addAll(page.messages.where((m) => !knownOlder.contains(m.id)));
        _messages = merged;
        _oldestMessageDocument = page.lastDocument ?? _oldestMessageDocument;
        _hasMoreMessages = page.hasMore;
        _loadingMoreMessages = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingMoreMessages = false);
      debugPrint('load older messages: $e');
    }
  }

  Future<void> _searchMessages() async {
    final id = await Navigator.of(context).push<String>(MaterialPageRoute(
        builder: (_) => MessageSearchScreen(chatId: _chatId)));
    if (!mounted || id == null || id.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _messageKeys[id];
      final target = key?.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 350), curve: Curves.easeOut, alignment: .45);
      }
    });
  }

  Future<void> _toggleMute() async {
    try {
      await _chat.muteChat(_chatId, !_muted);
    } catch (e) {
      debugPrint('mute chat: $e');
    }
  }

  Future<void> _deleteChatForMe() async { try { await _chat.deleteChat(_chatId); if(mounted)Navigator.of(context).pop(); } catch(e){debugPrint('delete chat: $e');} }

  Future<void> _togglePin() async {
    try {
      await _chat.pinChat(_chatId, !_pinned);
    } catch (e) {
      debugPrint('pin chat: $e');
    }
  }

  Future<void> _toggleMessagePin(MessageModel message) async { try { await _chat.pinMessage(_chatId, message.id, !message.isPinned); } catch (e) { debugPrint('pin message: $e'); } }

  Future<void> _deleteMessageForMe(MessageModel message) async { try { await _chat.deleteMessageForMe(_chatId, message.id); } catch (e) { debugPrint('delete message for me: $e'); } }
  Future<void> _editMessage(MessageModel message) async {
    final controller=TextEditingController(text: message.text ?? '');
    final result=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('تعديل الرسالة'),
      content:TextField(controller:controller,maxLines:5,autofocus:true,decoration:const InputDecoration(hintText:'نص الرسالة')),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,controller.text.trim()),child:const Text('حفظ'))]));
    controller.dispose();
    if(result==null||result.isEmpty||result==message.text?.trim())return;
    try{await _chat.editMessage(_chatId,message.id,result);}catch(e){if(mounted)ToastService.showError('تعذر تعديل الرسالة.');debugPrint('edit message: $e');}
  }
  Future<void> _confirmDeleteMessage(MessageModel message) async {
    final all=message.senderId==_auth.currentUser?.uid;
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(all?'حذف الرسالة؟':'حذف الرسالة لديك؟'),
      content:Text(all?'سيتم حذف الرسالة لدى جميع المشاركين.':'سيتم إخفاء الرسالة لديك فقط.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حذف'))]));
    if(ok!=true)return;
    if(all)await _deleteMessage(message);else await _deleteMessageForMe(message);
  }
  Future<void> _showPinnedMessages() async {
    try{
      final items=await _chat.getPinnedMessages(_chatId);
      if(!mounted)return;
      showModalBottomSheet<void>(context:context,isScrollControlled:true,builder:(ctx)=>SafeArea(child:SizedBox(
        height:MediaQuery.of(ctx).size.height*.55,
        child:Column(children:[
          const Padding(padding:EdgeInsets.all(16),child:Text('الرسائل المثبتة',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800))),
          Expanded(child:items.isEmpty?const Center(child:Text('لا توجد رسائل مثبتة')):ListView.separated(
            itemCount:items.length,separatorBuilder:(_,__)=>const Divider(height:1),
            itemBuilder:(_,i){final m=items[i];return ListTile(
              leading:const Icon(Icons.push_pin_outlined,color:AppColors.primary),
              title:Text(m.text?.isNotEmpty==true?m.text!:'مرفق',maxLines:2,overflow:TextOverflow.ellipsis),
              subtitle:Text(m.senderName),onTap:()=>Navigator.pop(ctx));}))
        ]))));
    }catch(e){if(mounted)ToastService.showError('تعذر تحميل الرسائل المثبتة.');debugPrint('pinned messages: $e');}
  }

  Future<void> _deleteMessage(MessageModel message) async {
    if (message.senderId != _auth.currentUser?.uid) return;
    try {
      await _chat.deleteMessage(_chatId, message.id);
    } catch (e) {
      debugPrint('delete message: $e');
    }
  }

  void _startReply(MessageModel message) {
    setState(() => _replyingTo = message);
    ChatReplyContext.instance.set(_chatId, message);
  }

  void _clearReply() {
    setState(() => _replyingTo = null);
    ChatReplyContext.instance.clear(_chatId);
  }

  Future<void> _shareLocation() async {
    try {
      final location = await Navigator.of(context).push<ChatLocationData>(
        MaterialPageRoute(builder: (_) => const ChatLocationPicker()),
      );
      if (!mounted || location == null) return;
      final url = 'https://www.openstreetmap.org/?mlat=${location.latitude}&mlon=${location.longitude}#map=18/${location.latitude}/${location.longitude}';
      await _chat.sendMessage(
        chatId: _chatId,
        text: location.address,
        locationUrl: url,
        locationLat: location.latitude,
        locationLng: location.longitude,
        locationAddress: location.address,
        metadata: {
          'locationStreet': location.street,
          'locationNeighborhood': location.neighborhood,
          'locationCity': location.city,
          'locationState': location.state,
          'locationCountry': location.country,
          'osmType': location.osmType,
          'osmId': location.osmId,
        },
      );
    } catch (e) {
      debugPrint('share chat location: $e');
      ToastService.showError('تعذر إرسال الموقع حالياً.');
    }
  }

  UploadStatus? _uploadStatusFor(Map<String, dynamic> message) {
    if (!message.containsKey('type')) return null;
    final type = message['type']?.toString();
    if (!{'image', 'video', 'audio', 'file'}.contains(type)) return null;
    if (message['isLocal'] == true) {
      switch (message['uploadStatus']?.toString()) {
        case 'failed':
        case 'retry':
        case 'share_retry':
          return UploadStatus.failed;
        case 'pending':
        case 'queued':
          return UploadStatus.pending;
        case 'uploading':
        case 'link_ready':
          // link_ready means the remote object/link exists, but the Firestore
          // message has not necessarily been published yet. Never show it as
          // delivered until the durable outbox reaches sent.
          return UploadStatus.uploading;
      }
      if (message['hasError'] == true) return UploadStatus.failed;
      if (message['isUploading'] == true) return UploadStatus.uploading;
    }
    if (message['isLocal'] != true &&
        message['senderId'] == _auth.currentUser?.uid) {
      // Firestore publication means "sent", not "delivered". Only the
      // receiver's acknowledgement may advance the indicator.
      if (message['isRead'] == true ||
          message['status']?.toString() == 'read') {
        return UploadStatus.read;
      }
      if (message['isDelivered'] == true ||
          message['status']?.toString() == 'delivered') {
        return UploadStatus.delivered;
      }
      return UploadStatus.sent;
    }
    return null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(_firestore.collection('users').doc(uid).set({'isOnline': true, 'lastSeen': FieldValue.serverTimestamp()}, SetOptions(merge: true)));
      unawaited(_markDeliveryAndRead());
    } else if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      unawaited(_firestore.collection('users').doc(uid).set({'isOnline': false, 'lastSeen': FieldValue.serverTimestamp()}, SetOptions(merge: true)));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      unawaited(_firestore.collection('users').doc(uid).set({'isOnline': false, 'lastSeen': FieldValue.serverTimestamp()}, SetOptions(merge: true)));
    }
    _pendingRefreshTimer?.cancel();
    _typingClearTimer?.cancel();
    _roomLoadTimer?.cancel();
    unawaited(_setTyping(false));
    _messagesSub?.cancel();
    _chatSub?.cancel();
    _userSub?.cancel();
    _scrollController.removeListener(_onChatScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final image = widget.otherUserImage ?? widget.groupImage;
    final all = <Map<String, dynamic>>[
      ..._localMedia,
      ..._messages.map((m) => m.toFirestore()..['id'] = m.id)
    ];
    all.sort((a, b) =>
        _messageTime(b['timestamp']).compareTo(_messageTime(a['timestamp'])));
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0B1121) : const Color(0xFFE3F1EF),
      appBar: AppBar(
        elevation: 0,
        leading: _selectionMode
            ? IconButton(icon: const Icon(Icons.close), onPressed: _clearSelection)
            : BackButton(color: dark ? null : AppColors.primary),
        backgroundColor: dark ? const Color(0xFF101827) : const Color(0xFFF7FBFA),
        foregroundColor: dark ? null : AppColors.primary,
        titleSpacing: 0,
        title: _selectionMode
            ? Text('${_selectedMessageIds.length} محددة')
            : StreamBuilder<UserStatusModel?>(
            stream: _statusService.streamUserStatus(widget.otherUserId),
            builder: (context, snapshot) {
              final status = snapshot.hasError ? null : snapshot.data;
              final hasStoryImage =
                  status != null &&
                  status.stories.isNotEmpty &&
                  status.stories.first.type == 'image' &&
                  status.stories.first.url.isNotEmpty;
              final presenceColor = _otherTyping
                  ? AppColors.primary
                  : _online
                      ? const Color(0xFF20B66B)
                      : AppColors.primary.withOpacity(.30);
              final avatar = InkWell(
                onTap: status != null && status.stories.isNotEmpty
                    ? () => _openOtherUserStatus(status)
                    : _profile,
                borderRadius: BorderRadius.circular(23),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: 44,
                      height: 44,
                      padding: EdgeInsets.all(_otherTyping || _online ? 2.2 : 1.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: status != null && status.stories.isNotEmpty
                              ? AppColors.primary
                              : presenceColor,
                          width: _otherTyping ? 2.2 : 1.3,
                        ),
                      ),
                      child: ClipOval(
                        child: hasStoryImage
                            ? CachedNetworkImage(
                                imageUrl: status.stories.first.url,
                                fit: BoxFit.cover,
                              )
                            : image != null && image.trim().isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: image.trim(),
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) =>
                                        _AvatarFallback(name: widget.otherUserName),
                                  )
                                : _AvatarFallback(name: widget.otherUserName),
                      ),
                    ),
                    if (_online)
                      PositionedDirectional(
                        end: -1,
                        bottom: -1,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFF20B66B),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: dark
                                  ? const Color(0xFF101827)
                                  : const Color(0xFFF7FBFA),
                              width: 2.2,
                            ),
                          ),
                        ),
                      ),
                    if (_otherTyping)
                      PositionedDirectional(
                        start: -3,
                        top: -3,
                        child: Container(
                          width: 19,
                          height: 19,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: dark
                                  ? const Color(0xFF101827)
                                  : const Color(0xFFF7FBFA),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              );
              return Row(children: [
                avatar,
                const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.isGroup ? null : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AccountInfoScreen(
                        userId: widget.otherUserId,
                        fallbackName: widget.otherUserName,
                        fallbackPhoto: widget.otherUserImage,
                      ),
                    ),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(widget.isGroup ? 'المجموعة' : widget.otherUserName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: dark ? null : AppColors.primary)),
                    Text(
                        _otherTyping
                            ? 'يكتب الآن...'
                            : (_online ? 'متصل الآن' : _lastSeenLabel()),
                        style: TextStyle(
                            fontSize: 11,
                            color: _otherTyping
                                ? AppColors.primary
                                : (_online ? Colors.green : Colors.grey)))
                  ])),
                ),
              ]);
            },
          ),
        actions: _selectionMode ? [
          IconButton(tooltip: 'نسخ', onPressed: _copySelectedMessages, icon: const Icon(Icons.copy_outlined)),
          IconButton(tooltip: 'حفظ', onPressed: _starSelectedMessages, icon: const Icon(Icons.star_border)),
          IconButton(tooltip: 'حذف', onPressed: _deleteSelectedMessages, icon: const Icon(Icons.delete_outline)),
        ] : [
          IconButton(
              onPressed: _searchMessages,
              tooltip: 'البحث داخل الرسائل',
              icon: Icon(Icons.search_rounded,
                  color: dark ? null : AppColors.primary)),
          if (!widget.isGroup)
            IconButton(
                onPressed: () => _call(false),
                icon: Icon(Icons.call_rounded,
                    color: dark ? null : AppColors.primary)),
          if (!widget.isGroup)
            IconButton(
                onPressed: () => _call(true),
                icon: Icon(Icons.videocam_rounded,
                    color: dark ? null : AppColors.primary)),
          PopupMenuButton<String>(
              iconColor: dark ? null : AppColors.primary,
              onSelected: (value) {
                if (value == 'mute') _toggleMute();
                if (value == 'pin') _togglePin();
                if (value == 'pinned') _showPinnedMessages();
                if (value == 'starred') _showStarredMessages();
                if (value == 'profile') _profile();
                if (value == 'groupInfo') _openGroupInfo();
                if (value == 'delete') _deleteChatForMe();
                if (value == 'settings') _openChatSettings();
              },
              itemBuilder: (_) => [
                    if (widget.isGroup) const PopupMenuItem(value: 'groupInfo', child: Text('معلومات المجموعة')),
                    if (!widget.isGroup) const PopupMenuItem(value: 'profile', child: Text('معلومات جهة الاتصال')),
                    const PopupMenuItem(value: 'settings', child: Text('تخصيص المحادثة')),
                    const PopupMenuItem(value: 'pinned', child: Text('الرسائل المثبتة')),
                    const PopupMenuItem(value: 'starred', child: Text('الرسائل المحفوظة')),
                    PopupMenuItem(value: 'mute', child: Text(_muted ? 'إلغاء كتم الإشعارات' : 'كتم الإشعارات')),
                    PopupMenuItem(value: 'pin', child: Text(_pinned ? 'إلغاء تثبيت المحادثة' : 'تثبيت المحادثة')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'delete', child: Text('حذف المحادثة لدي')),
                  ])
        ],
      ),
      body: Column(children: [
        Expanded(
            child: ChatBackground(
                scrollController: _scrollController,
                wallpaper: _wallpaper,
                child: Stack(children: [
          if (_loadError != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, size: 44, color: AppColors.primary.withOpacity(.75)),
                    const SizedBox(height: 12),
                    Text(_loadError!, textAlign: TextAlign.center, style: TextStyle(color: dark ? Colors.white70 : const Color(0xFF49615E), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 14),
                    FilledButton.icon(onPressed: () { setState(() { _loadError = null; _loading = true; }); _initializeRoom(); }, icon: const Icon(Icons.refresh_rounded), label: const Text('إعادة المحاولة')),
                  ],
                ),
              ),
            )
          else if (_loading)
            const Center(
              child: CircularProgressIndicator(),
            )
          else if (all.isEmpty)
            Center(
                child: Text('ابدأ المحادثة',
                    style: TextStyle(
                        color: dark ? Colors.white70 : const Color(0xFF49615E),
                        fontWeight: FontWeight.w600)))
          else
            ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(8),
                itemCount: all.length,
                controller: _scrollController,
                itemBuilder: (_, index) {
                  final message = all[index];
                  final older = index + 1 < all.length ? all[index + 1] : null;
                  final currentDate = _messageTime(message['timestamp']);
                  final olderDate = older == null ? null : _messageTime(older['timestamp']);
                  final showDate = older == null || currentDate.year != olderDate!.year || currentDate.month != olderDate.month || currentDate.day != olderDate.day;
                  final remote = message['isLocal'] != true;
                  final rawMessageId = message['id']?.toString();
                  final model = remote && rawMessageId != null
                      ? _messages.firstWhere(
                          (m) => m.id == rawMessageId,
                          orElse: () => MessageModel(
                              id: '', chatId: '', senderId: '', senderName: ''))
                      : null;
                  final status = _uploadStatusFor(message);
                  final messageId = rawMessageId ?? index.toString();
                  Widget bubble = MessageBubble(
                      key: ValueKey(messageId),
                      message: message,
                      isFirstInChat: index == all.length - 1,
                      isMe: message['senderId'] == _auth.currentUser?.uid ||
                          message['isLocal'] == true,
                      onReply: model == null || model.id.isEmpty
                          ? null
                          : () => _startReply(model),
                      onForward: model == null || model.id.isEmpty
                          ? null
                          : () => _forwardMessage(model),
                      onReplyPreviewTap: () {
                        final preview = message['replyPreview'];
                        final replyId = message['replyToId']?.toString() ?? (preview is Map ? preview['id']?.toString() : null);
                        if (replyId != null && replyId.isNotEmpty) unawaited(_jumpToMessage(replyId));
                      },
                      onDelete: model == null || model.id.isEmpty || model.senderId != _auth.currentUser?.uid ? null : () => _confirmDeleteMessage(model),
                      onEdit: model == null || model.id.isEmpty || model.senderId != _auth.currentUser?.uid ? null : () => _editMessage(model),
                      onDeleteForMe: model == null || model.id.isEmpty
                          ? null
                          : () => _deleteMessageForMe(model),
                      onPin: model == null || model.id.isEmpty
                          ? null
                          : () => _toggleMessagePin(model),
                      onStar: model == null || model.id.isEmpty
                          ? null
                          : () => _toggleMessageStar(model),
                      onSelect: model == null || model.id.isEmpty ? null : () => _toggleMessageSelection(model.id),
                      fontSize: _fontSize,
                      onReaction: remote && messageId != null
                          ? (emoji) => _chat.addReaction(
                              _chatId, messageId, emoji)
                          : null);
                  if (messageId != null && _newMessageIds.contains(messageId)) {
                    bubble = TweenAnimationBuilder<double>(
                        key: ValueKey('entrance-$messageId'),
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) => Opacity(
                            opacity: value,
                            child: Transform.translate(
                                offset: Offset(0, 10 * (1 - value)),
                                child: child)),
                        child: bubble);
                  }
                  Widget messageWidget = status == null
                      ? bubble
                      : Stack(clipBehavior: Clip.none, children: [
                          bubble,
                          MediaUploadStatusWidget(
                              status: status,
                              progress:
                                  (message['uploadProgress'] as num?)?.toDouble() ??
                                      0.0,
                              onRetry: () => message['onRetry']?.call(),
                              onCancel: () => message['onCancel']?.call())
                        ]);
                  if (model != null && model.id.isNotEmpty) {
                    messageWidget = _SwipeToReply(
                      onReply: () => _startReply(model),
                      child: messageWidget,
                    );
                  }
                  return Column(
                    children: [
                      if (showDate) Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: dark ? Colors.white10 : Colors.white.withOpacity(.72), borderRadius: BorderRadius.circular(14)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            child: Text('${currentDate.day.toString().padLeft(2, '0')}/${currentDate.month.toString().padLeft(2, '0')}/${currentDate.year}', style: TextStyle(fontSize: 10, color: dark ? Colors.white70 : const Color(0xFF49615E), fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                      messageWidget,
                    ],
                  );
                }),
          if (_showNewMessages)
            Positioned(
              right: 14,
              bottom: 14,
              child: Material(
                color: AppColors.primary,
                elevation: 5,
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  onTap: _scrollToLatest,
                  borderRadius: BorderRadius.circular(22),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.keyboard_double_arrow_down_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 5),
                      Text('رسائل جديدة', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
            ),
          if (_loadingMoreMessages)
            const Positioned(top: 8, left: 0, right: 0, child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),),
          if (_loading)
            Positioned.fill(
                child: IgnorePointer(
                    child: ColoredBox(
                        color: dark
                            ? const Color(0xFF0B1121).withOpacity(.12)
                            : const Color(0xFFE3F1EF).withOpacity(.12),
                        child: Center(
                            child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: AppColors.primary))))))
        ]))),
        AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1,
                child: FadeTransition(opacity: animation, child: child)),
            child: _replyingTo == null
                ? const SizedBox.shrink(key: ValueKey('no-reply'))
                : _replyBanner(_replyingTo!)),
        ChatInputBar(
            chatId: _chatId,
            replyToId: _replyingTo?.id,
            onSendMessage: (text, clientTimestamp) {
              unawaited(_setTyping(false));
              final replyingTo = _replyingTo;
              final replyPreview = replyingTo == null
                  ? null
                  : <String, dynamic>{
                      'id': replyingTo.id,
                      'senderId': replyingTo.senderId,
                      'senderName': replyingTo.senderName,
                      'text': replyingTo.text ?? '',
                      'type': replyingTo.type.name,
                    };
              _optimisticallyAddTextMessage(
                text,
                clientTimestamp: clientTimestamp,
                replyToId: replyingTo?.id,
                replyPreview: replyPreview,
              );
              if (replyingTo != null) _clearReply();
            },
            onTyping: _setTyping,
            onSendImage: (_) {},
            onLocalMedia: _addLocalMedia,
            onShareLocation: _shareLocation,
          ),
      ]),
    );
  }

  Widget _replyBanner(MessageModel message) {
    final text = message.text?.trim().isNotEmpty == true
        ? message.text!.trim()
        : _replyTypeLabel(message.type);
    return Material(
        key: ValueKey('reply-${message.id}'),
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF162039)
            : const Color(0xFFF7FBFA),
        child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: BoxDecoration(
                border: Border(
                    top:
                        BorderSide(color: AppColors.primary.withOpacity(.35)))),
            child: Row(children: [
              Container(
                  width: 3,
                  height: 38,
                  decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 9),
              const Icon(Icons.reply, color: AppColors.primary, size: 19),
              const SizedBox(width: 7),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('الرد على ${message.senderName}',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700)),
                    Text(text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12))
                  ])),
              IconButton(
                  onPressed: _clearReply,
                  icon: const Icon(Icons.close, size: 19))
            ])));
  }

  String _replyTypeLabel(MessageType type) {
    switch (type) {
      case MessageType.image:
        return 'صورة';
      case MessageType.video:
        return 'فيديو';
      case MessageType.audio:
        return 'رسالة صوتية';
      case MessageType.file:
        return 'ملف';
      case MessageType.location:
        return 'موقع';
      default:
        return 'رسالة';
    }
  }
}
