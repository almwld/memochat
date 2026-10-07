import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/conversation.dart';
import '../../../core/repositories/chat_repository.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/notifications/notification_inbox.dart';
import '../../../core/widgets/premium_ui.dart';
import '../../../core/widgets/advanced_feature_carousel.dart';
import 'chat_room_screen.dart';
import 'chat_navigation.dart';
import '../../../core/models/chat_folder.dart';
import '../../../core/services/chat_folder_service.dart';
import 'folders_manager_screen.dart';
import '../../../core/deeplink/invite_handler.dart';
import '../services/chat_service.dart';
import '../../notifications/presentation/notification_center_screen.dart';
import '../../shake/presentation/shake_screen.dart';
import '../models/status_model.dart';
import '../services/status_service.dart';
import '../presentation/story_viewer_screen.dart';
import '../presentation/add_status_screen.dart';
import 'create_group_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({required this.repository, this.onNewChat, super.key});
  final ChatRepository repository;
  final VoidCallback? onNewChat;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _inbox = NotificationInbox();
  late final Stream<List<Conversation>> _conversationsStream;
  late Future<int> _unreadNotifications;
  _ConversationFilter _conversationFilter = _ConversationFilter.all;
  bool _showArchived = false;
  final _folderService = ChatFolderService();
  ChatFolder? _activeFolder;
  StreamSubscription<Uri>? _inviteSubscription;
  // Keep the last successful snapshot visible if Firestore briefly terminates a stream.
  List<Conversation> _lastConversations = const <Conversation>[];

  @override
  void initState() {
    super.initState();
    _conversationsStream = widget.repository.watchConversations();
    _inviteSubscription = InviteHandler.instance.links.listen(_handleInvite);
    _unreadNotifications = _inbox.unreadCount();
    unawaited(_loadActiveFolder());
  }

  Future<void> _loadActiveFolder() async {
    final folders = await _folderService.getFolders();
    if (!mounted) return;
    if (_activeFolder != null &&
        !folders.any((folder) => folder.id == _activeFolder!.id)) {
      setState(() => _activeFolder = null);
    }
  }

  Future<void> _openCreateGroup() async {
    final createdId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
    );
    if (!mounted) return;
    setState(() {});
    if (createdId == null || createdId.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance.collection('chats').doc(createdId).get();
      final data = snap.data() ?? const <String, dynamic>{};
      final groupName = data['groupName']?.toString().trim();
      if (!snap.exists || data['isGroup'] != true) return;
      await ChatNavigation.openRoom(context,chatId:createdId,otherUserId:'',otherUserName:groupName?.isNotEmpty==true?groupName!:'مجموعة',otherUserImage:data['groupPhoto']?.toString(),isGroup:true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إنشاء المجموعة، لكن تعذر فتح الغرفة: $e')),
        );
      }
    }
  }

  Future<void> _handleInvite(Uri uri) async {
    if (!mounted) return;
    final link = uri.toString();
    final join = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('دعوة إلى مجموعة'), content: const Text('هل تريد الانضمام إلى المجموعة عبر هذا الرابط؟'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('انضمام'))]));
    if (join != true) return;
    try {
      final id = await ChatService().joinByInviteLink(link);
      final snap = await FirebaseFirestore.instance.collection('chats').doc(id).get();
      final data = snap.data() ?? const <String,dynamic>{};
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final participants = List<String>.from(data['participants'] as List? ?? const []);
      final other = participants.firstWhere((v) => v != uid, orElse: () => '');
      if (!mounted || other.isEmpty) return;
      await ChatNavigation.openRoom(context,chatId:id,otherUserId:other,otherUserName:data['groupName']?.toString()??'مجموعة',isGroup:true);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر الانضمام: ' + e.toString()))); }
  }

  @override
  void dispose() { _inviteSubscription?.cancel(); _search.dispose(); _searchFocus.dispose(); super.dispose(); }

  Future<void> _openFolders() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FoldersManagerScreen()));
    await _loadActiveFolder();
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
    );
    if (mounted) setState(() => _unreadNotifications = _inbox.unreadCount());
  }

  @override
  Widget build(BuildContext context) => ScrollAwareScaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(142),
          child: _MemoChatHeader(
            searchController: _search,
            searchFocus: _searchFocus,
            unreadFuture: _unreadNotifications,
            onNotifications: _openNotifications,
            onNewGroup: _openCreateGroup,
            onShake: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ShakeScreen(repository: widget.repository),
              ),
            ),
            onSearchChanged: () => setState(() {}),
          ),
        ),
        body: StreamBuilder<List<Conversation>>(
          stream: _conversationsStream,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              _lastConversations =
                  List<Conversation>.unmodifiable(snapshot.data!);
            }

            // Do not blank an already-loaded inbox because of a transient
            // Firestore/network/auth stream error.
            // A Firestore/network error is never allowed to replace the
            // inbox with a fatal error page. Keep the last successful snapshot
            // visible; on a first offline open, render the normal empty state.
            final hasRenderableData =
                snapshot.hasData || _lastConversations.isNotEmpty;
            if (!hasRenderableData && snapshot.hasError) {
              return _StateView(
                icon: AppIcons.chat,
                title: 'لا توجد محادثات محفوظة',
                subtitle: 'أنت غير متصل حالياً. ستظهر محادثاتك تلقائياً عند عودة الاتصال.',
              );
            }
            if (!hasRenderableData) {
              return const Center(child: CircularProgressIndicator());
            }
            final conversations = snapshot.data ?? _lastConversations;
            final filtered = _filtered(conversations);
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: AdvancedFeatureCarousel(
                      title: 'مساحتك الخاصة',
                      onClose: null,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: StreamBuilder<List<UserStatusModel>>(
                      stream: StatusService().streamActiveStatuses(),
                      builder: (context, snapshot) {
                        final statuses = snapshot.data ?? const <UserStatusModel>[];
                        final uid = FirebaseAuth.instance.currentUser?.uid;
                        final mine = uid == null
                            ? null
                            : statuses.where((status) => status.userId == uid).firstOrNull;
                        final mineImageFuture = uid == null
                            ? Future<String?>.value(null)
                            : _loadCurrentProfileImage(uid);
                        final others = statuses
                            .where((status) => status.userId != uid)
                            .toList()
                          ..sort((a, b) {
                            if (a.isViewed != b.isViewed) return a.isViewed ? 1 : -1;
                            return b.createdAt.compareTo(a.createdAt);
                          });
                        return SizedBox(
                          height: 154,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: others.length + 1,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return FutureBuilder<String?>(
                                  future: mineImageFuture,
                                  builder: (context, imageSnapshot) =>
                                      _StatusAddTile(
                                    status: mine,
                                    imageOverride: imageSnapshot.data,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => mine == null
                                            ? const AddStatusScreen()
                                            : StoryViewerScreen(status: mine),
                                      ),
                                    ),
                                  ),
                                );
                              }
                              final status = others[index - 1];
                              return _StatusTile(
                                status: status,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => StoryViewerScreen(status: status),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),

                  ),
                ),
                SliverToBoxAdapter(child: _buildCategoryBar()),
                if (filtered.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _StateView(
                      icon: AppIcons.message,
                      title: 'ابدأ أول محادثة',
                      subtitle: 'انتقل إلى «تواصل» للعثور على أشخاص وابدأ محادثة جديدة.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                    sliver: SliverList.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return _ConversationCard(
                          conversation: item,
                          onMarkUnread: () => widget.repository.markAsUnread(item.id),
                          onArchive: () => _toggleArchive(item),
                          onFolder: () => _assignChatToFolder(item.id),
                          onTap: () => ChatNavigation.openRoom(context,chatId:item.id,otherUserId:item.isGroup?'':item.participant.id,otherUserName:item.participant.displayName,otherUserImage:item.participant.avatarUrl,isGroup:item.isGroup),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
        floatingActionButton: widget.onNewChat == null
            ? null
            : FloatingActionButton.extended(
                onPressed: widget.onNewChat,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('محادثة جديدة'),
              ),
      );

  Future<String?> _loadCurrentProfileImage(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data() ?? const <String, dynamic>{};
      final stored = data['photoUrl']?.toString().trim();
      if (stored?.isNotEmpty == true) return stored;
      final legacy = data['photoURL']?.toString().trim();
      if (legacy?.isNotEmpty == true) return legacy;
    } catch (_) {}
    return FirebaseAuth.instance.currentUser?.photoURL;
  }

  Future<void> _assignChatToFolder(String chatId) async {
    final folders = await _folderService.getFolders();
    if (!mounted || folders.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أنشئ مجلدًا أولًا')));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('تنظيم المحادثة', style: TextStyle(fontWeight: FontWeight.w800))),
          for (final folder in folders)
            FutureBuilder<bool>(
              future: Future.value(folder.chatIds.contains(chatId)),
              builder: (_, snap) => CheckboxListTile(
                value: snap.data ?? false,
                title: Text(folder.name),
                onChanged: (value) async {
                  await _folderService.setChatInFolder(folder.id, chatId, value == true);
                  if (context.mounted) Navigator.pop(context);
                  if (mounted) setState(() {});
                },
              ),
            ),
        ]),
      ),
    );
  }

  Future<void> _toggleArchive(Conversation item) async {
    await ChatService().archiveChat(item.id, !item.isArchived);
    if (mounted) setState(() {});
  }

  Widget _buildCategoryBar() => FutureBuilder<List<ChatFolder>>(
    future: _folderService.getFolders(),
    builder: (context, snapshot) {
      final folders = snapshot.data ?? const <ChatFolder>[];
      final items = <Widget>[
        ChoiceChip(
          label: const Text('كل البحث'),
          selected: _conversationFilter == _ConversationFilter.all &&
              !_showArchived &&
              _activeFolder == null &&
              _search.text.trim().isEmpty,
          onSelected: (_) => setState(() {
            _search.clear();
            _conversationFilter = _ConversationFilter.all;
            _showArchived = false;
            _activeFolder = null;
          }),
        ),
        ChoiceChip(
          label: const Text('المحادثات'),
          selected: _conversationFilter == _ConversationFilter.all &&
              !_showArchived &&
              _activeFolder == null,
          onSelected: (_) => setState(() {
            _conversationFilter = _ConversationFilter.all;
            _showArchived = false;
            _activeFolder = null;
          }),
        ),
        ActionChip(
          avatar: const Icon(Icons.tune, size: 17),
          label: const Text('المجلدات'),
          onPressed: _openFolders,
        ),
        FilterChip(
          avatar: const Icon(Icons.archive_outlined, size: 17),
          label: const Text('المؤرشفة'),
          selected: _showArchived,
          onSelected: (value) => setState(() {
            _showArchived = value;
            if (value) _activeFolder = null;
          }),
        ),
        ChoiceChip(
          label: const Text('الكل'),
          selected: _conversationFilter == _ConversationFilter.all &&
              !_showArchived &&
              _activeFolder == null,
          onSelected: (_) => setState(() {
            _conversationFilter = _ConversationFilter.all;
            _showArchived = false;
            _activeFolder = null;
          }),
        ),
        ChoiceChip(
          label: const Text('غير مقروءة'),
          selected: _conversationFilter == _ConversationFilter.unread,
          onSelected: (_) => setState(() {
            _conversationFilter = _ConversationFilter.unread;
            _showArchived = false;
          }),
        ),
        ChoiceChip(
          label: const Text('متصلون'),
          selected: _conversationFilter == _ConversationFilter.online,
          onSelected: (_) => setState(() {
            _conversationFilter = _ConversationFilter.online;
            _showArchived = false;
          }),
        ),
        ...folders.map(
          (folder) => ChoiceChip(
            label: Text(folder.name),
            selected: _activeFolder?.id == folder.id,
            onSelected: (_) => setState(() {
              _activeFolder = folder;
              _showArchived = false;
            }),
          ),
        ),
      ];

      return SizedBox(
        height: 52,
        child: ListView.separated(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 10),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, index) => items[index],
        ),
      );
    },
  );

  List<Conversation> _filtered(List<Conversation> source) {
    final query = _search.text.trim().toLowerCase();
    return source.where((item) {
      final name = item.participant.displayName.toLowerCase();
      final text = item.lastMessage?.text.toLowerCase() ?? '';
      final matchesSearch = query.isEmpty || name.contains(query) || text.contains(query);
      final matchesArchive = _showArchived ? item.isArchived : !item.isArchived;
      final matchesFolder = _activeFolder == null || _activeFolder!.chatIds.contains(item.id);
      final matchesFilter = switch (_conversationFilter) {
        _ConversationFilter.all => true,
        _ConversationFilter.unread => item.unreadCount > 0,
        _ConversationFilter.online => item.participant.isOnline,
      };
      return matchesSearch && matchesArchive && matchesFilter && matchesFolder;
    }).toList();
  }

}

enum _ConversationFilter { all, unread, online }

class _MemoChatHeader extends StatelessWidget {
  const _MemoChatHeader({
    required this.searchController,
    required this.searchFocus,
    required this.unreadFuture,
    required this.onNotifications,
    required this.onNewGroup,
    required this.onShake,
    required this.onSearchChanged,
  });

  final TextEditingController searchController;
  final FocusNode searchFocus;
  final Future<int> unreadFuture;
  final VoidCallback onNotifications;
  final VoidCallback onNewGroup;
  final VoidCallback onShake;
  final VoidCallback onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: const BorderRadiusDirectional.only(
                        topStart: Radius.circular(16),
                        topEnd: Radius.circular(8),
                        bottomEnd: Radius.circular(16),
                        bottomStart: Radius.circular(8),
                      ),
                    ),
                    child: Icon(
                      Icons.forum_rounded,
                      color: scheme.onPrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MemoChat',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.3,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'مساحتك للحديث',
                          style: TextStyle(fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  _HeaderIconButton(
                    icon: Icons.group_add_outlined,
                    tooltip: 'مجموعة جديدة',
                    onPressed: onNewGroup,
                  ),
                  _HeaderIconButton(
                    icon: Icons.vibration_rounded,
                    tooltip: 'رجّ للتعارف',
                    onPressed: onShake,
                  ),
                  FutureBuilder<int>(
                    future: unreadFuture,
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _HeaderIconButton(
                            icon: Icons.notifications_none_rounded,
                            tooltip: 'الإشعارات',
                            onPressed: onNotifications,
                          ),
                          if (count > 0)
                            PositionedDirectional(
                              top: -2,
                              end: -1,
                              child: Container(
                                constraints: const BoxConstraints(
                                  minWidth: 17,
                                  minHeight: 17,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  border: Border.all(
                                    color: Theme.of(context).scaffoldBackgroundColor,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  count > 99 ? '99+' : '$count',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: scheme.onPrimary,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: searchController,
                builder: (context, value, _) {
                  return Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withOpacity(.62),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: value.text.trim().isEmpty
                            ? scheme.outlineVariant.withOpacity(.45)
                            : scheme.primary.withOpacity(.55),
                      ),
                    ),
                    child: TextField(
                      controller: searchController,
                      focusNode: searchFocus,
                      onChanged: (_) => onSearchChanged(),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'ابحث في محادثاتك',
                        prefixIcon: const Icon(Icons.search_rounded, size: 21),
                        suffixIcon: value.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'مسح البحث',
                                onPressed: searchController.clear,
                                icon: const Icon(Icons.close_rounded, size: 19),
                              ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      splashRadius: 22,
      icon: Icon(icon, size: 22),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
    required this.conversation,
    required this.onTap,
    required this.onMarkUnread,
    required this.onArchive,
    required this.onFolder,
  });

  final Conversation conversation;
  final VoidCallback onTap;
  final Future<void> Function() onMarkUnread;
  final Future<void> Function() onArchive;
  final VoidCallback onFolder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = conversation.participant;
    final last = conversation.lastMessage;
    final unread = conversation.unreadCount > 0;
    final preview = _preview(last);
    final previewColor = conversation.isTyping
        ? scheme.primary
        : unread
            ? scheme.onSurface
            : scheme.onSurfaceVariant;

    return RepaintBoundary(
      child: Dismissible(
        key: ValueKey('conversation-${conversation.id}'),
        direction: DismissDirection.horizontal,
        resizeDuration: const Duration(milliseconds: 180),
        movementDuration: const Duration(milliseconds: 220),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            await onMarkUnread();
            return false;
          }
          await onArchive();
          return true;
        },
        background: _SwipeAction(
          alignment: AlignmentDirectional.centerStart,
          icon: Icons.mark_chat_unread_rounded,
          label: 'غير مقروءة',
          color: scheme.primary,
        ),
        secondaryBackground: _SwipeAction(
          alignment: AlignmentDirectional.centerEnd,
          icon: conversation.isArchived
              ? Icons.unarchive_rounded
              : Icons.archive_outlined,
          label: conversation.isArchived ? 'إلغاء الأرشفة' : 'أرشفة',
          color: scheme.secondary,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: unread
                ? scheme.primaryContainer.withOpacity(.24)
                : scheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: unread
                  ? scheme.primary.withOpacity(.38)
                  : scheme.outlineVariant.withOpacity(.42),
              width: unread ? 1.3 : 1,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: onTap,
              onLongPress: onMarkUnread,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 11, 10, 11),
                child: Row(
                  children: [
                    _ConversationAvatar(user: user, unread: unread),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 80,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          user.displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 15.5,
                                            fontWeight: unread
                                                ? FontWeight.w900
                                                : FontWeight.w800,
                                            letterSpacing: -.1,
                                          ),
                                        ),
                                      ),
                                      if (conversation.isGroup) ...[
                                        const SizedBox(width: 5),
                                        Icon(
                                          Icons.groups_2_rounded,
                                          size: 15,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (conversation.isPinned)
                                  Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                      end: 4,
                                    ),
                                    child: Icon(
                                      Icons.push_pin_rounded,
                                      size: 14,
                                      color: scheme.primary,
                                    ),
                                  ),
                                Text(
                                  last == null
                                      ? ''
                                      : _formatConversationTime(last.createdAt),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: unread
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    color: unread
                                        ? scheme.primary
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Expanded(
                              child: Row(
                                children: [
                                  if (last?.isMine == true &&
                                      !conversation.isTyping) ...[
                                    _MessageStateIcon(
                                      status: last!.status,
                                      color: unread
                                          ? scheme.primary
                                          : scheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Expanded(
                                    child: conversation.isTyping
                                        ? Row(
                                            children: [
                                              _TypingDots(color: scheme.primary),
                                              const SizedBox(width: 6),
                                              Text(
                                                'يكتب الآن',
                                                style: TextStyle(
                                                  color: scheme.primary,
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Row(
                                            children: [
                                              Icon(
                                                _previewIcon(last),
                                                size: 16,
                                                color: previewColor,
                                              ),
                                              const SizedBox(width: 5),
                                              Expanded(
                                                child: Text(
                                                  preview,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: previewColor,
                                                    fontSize: 12.5,
                                                    fontWeight: unread
                                                        ? FontWeight.w700
                                                        : FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                  if (conversation.isMuted)
                                    Padding(
                                      padding: const EdgeInsetsDirectional.only(
                                        start: 6,
                                      ),
                                      child: Icon(
                                        Icons.notifications_off_rounded,
                                        size: 15,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  if (unread) ...[
                                    const SizedBox(width: 7),
                                    AnimatedScale(
                                      scale: unread ? 1 : .7,
                                      duration:
                                          const Duration(milliseconds: 220),
                                      curve: Curves.easeOutBack,
                                      child: Container(
                                        constraints:
                                            const BoxConstraints(minWidth: 22),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: scheme.primary,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          conversation.unreadCount > 99
                                              ? '99+'
                                              : conversation.unreadCount
                                                  .toString(),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: scheme.onPrimary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            _LastCallStatus(chatId: conversation.id),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    PopupMenuButton<String>(
                      tooltip: 'خيارات المحادثة',
                      padding: EdgeInsets.zero,
                      iconSize: 20,
                      onSelected: (value) {
                        if (value == 'unread') onMarkUnread();
                        if (value == 'archive') onArchive();
                        if (value == 'folder') onFolder();
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'unread',
                          child: Text('تحديد كغير مقروءة'),
                        ),
                        PopupMenuItem(
                          value: 'archive',
                          child: Text(
                            conversation.isArchived
                                ? 'إلغاء الأرشفة'
                                : 'أرشفة',
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'folder',
                          child: Text('تنظيم في مجلد'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _preview(ChatMessage? message) {
    if (message == null) return 'ابدأ المحادثة الآن';
    switch (message.type) {
      case MessageType.image:
        return 'صورة';
      case MessageType.video:
        return 'فيديو';
      case MessageType.file:
        return 'ملف';
      case MessageType.audio:
        return 'رسالة صوتية';
      case MessageType.text:
        return message.text.trim().isEmpty ? 'رسالة' : message.text.trim();
    }
  }

  static IconData _previewIcon(ChatMessage? message) {
    if (message == null) return Icons.chat_bubble_outline_rounded;
    switch (message.type) {
      case MessageType.image:
        return Icons.photo_outlined;
      case MessageType.video:
        return Icons.videocam_outlined;
      case MessageType.file:
        return Icons.attach_file_rounded;
      case MessageType.audio:
        return Icons.graphic_eq_rounded;
      case MessageType.text:
        return Icons.chat_bubble_outline_rounded;
    }
  }

  static String _formatConversationTime(DateTime date) {
    final now = DateTime.now();
    final local = date.toLocal();
    if (now.year == local.year &&
        now.month == local.month &&
        now.day == local.day) {
      final hour = local.hour == 0
          ? 12
          : local.hour > 12
              ? local.hour - 12
              : local.hour;
      final minute = local.minute.toString().padLeft(2, '0');
      final period = local.hour >= 12 ? 'م' : 'ص';
      return hour.toString() + ':' + minute + ' ' + period;
    }
    if (now.difference(local).inDays < 7) {
      const days = [
        'الإثنين',
        'الثلاثاء',
        'الأربعاء',
        'الخميس',
        'الجمعة',
        'السبت',
        'الأحد',
      ];
      return days[local.weekday - 1];
    }
    return local.day.toString() + '/' + local.month.toString();
  }
}

class _SwipeAction extends StatelessWidget {
  const _SwipeAction({
    required this.alignment,
    required this.icon,
    required this.label,
    required this.color,
  });

  final AlignmentGeometry alignment;
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(.13),
        borderRadius: BorderRadius.circular(22),
      ),
      alignment: alignment,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 22),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _LastCallStatus extends StatelessWidget {
  const _LastCallStatus({required this.chatId});

  final String chatId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('calls')
          .where('chatId', isEqualTo: chatId)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final docs = [...snapshot.data!.docs];
        docs.sort((a, b) {
          final aData = a.data();
          final bData = b.data();
          final aTime = _callTime(aData);
          final bTime = _callTime(bData);
          return bTime.compareTo(aTime);
        });
        final data = docs.first.data();
        final status = data['status']?.toString().trim() ?? '';
        final type = data['callType']?.toString().trim() ??
            (data['isVideoCall'] == true ? 'video' : 'audio');
        final statusText = _callStatusText(status);
        if (statusText == null) return const SizedBox.shrink();

        final icon = type == 'video'
            ? Icons.videocam_outlined
            : Icons.call_outlined;
        final tone = status == 'connected' || status == 'ended'
            ? scheme.onSurfaceVariant
            : scheme.primary;

        return Row(
          children: [
            Icon(icon, size: 13, color: tone),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'آخر مكالمة: $statusText',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tone,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static DateTime _callTime(Map<String, dynamic> data) {
    final value = data['updatedAt'] ?? data['endedAt'] ?? data['startedAt'];
    if (value is Timestamp) return value.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String? _callStatusText(String status) {
    switch (status) {
      case 'calling':
        return 'جارٍ الاتصال';
      case 'ringing':
        return 'يرن';
      case 'connected':
        return 'متصل';
      case 'ended':
        return 'انتهت';
      case 'missed':
        return 'فائتة';
      case 'rejected':
        return 'مرفوضة';
      case 'busy':
        return 'مشغول';
      case 'cancelled':
        return 'ملغاة';
      default:
        return null;
    }
  }
}

class _ConversationAvatar extends StatelessWidget {
  const _ConversationAvatar({required this.user, required this.unread});

  final ChatUser user;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final image = user.avatarUrl?.trim() ?? '';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 58,
          height: 58,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: unread ? scheme.primary : scheme.outlineVariant.withOpacity(.65),
              width: unread ? 2 : 1,
            ),
          ),
          child: CircleAvatar(
            backgroundColor: scheme.primaryContainer,
            backgroundImage: image.isEmpty ? null : NetworkImage(image),
            child: image.isNotEmpty
                ? null
                : Text(
                    user.displayName.characters.first,
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w900,
                      fontSize: 19,
                    ),
                  ),
          ),
        ),
        if (user.isOnline)
          PositionedDirectional(
            bottom: -1,
            end: -1,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFF20B66B),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MessageStateIcon extends StatelessWidget {
  const _MessageStateIcon({required this.status, required this.color});

  final MessageStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return Icon(Icons.schedule_rounded, size: 14, color: color);
      case MessageStatus.sent:
        return Icon(Icons.check_rounded, size: 15, color: color);
      case MessageStatus.delivered:
        return Icon(Icons.done_all_rounded, size: 15, color: color);
      case MessageStatus.read:
        return Icon(Icons.done_all_rounded, size: 15, color: color);
      case MessageStatus.failed:
        return Icon(Icons.error_outline_rounded, size: 15, color: color);
    }
  }
}

class _TypingDots extends StatelessWidget {
  const _TypingDots({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (index) => Padding(
            padding: EdgeInsetsDirectional.only(end: index == 2 ? 0 : 2),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
}

class _StateView extends StatelessWidget {
  const _StateView({required this.icon, required this.title, required this.subtitle, this.action});
  final AppIconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PremiumIconTile(icon: icon, size: 76, iconSize: 36),
              const SizedBox(height: 18),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5)),
              if (action != null) ...[const SizedBox(height: 18), action!],
            ],
          ),
        ),
      );
}


class _StatusAddTile extends StatelessWidget {
  const _StatusAddTile({required this.status, required this.imageOverride, required this.onTap});
  final UserStatusModel? status;
  final String? imageOverride;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final image = (imageOverride?.trim().isNotEmpty == true
            ? imageOverride!.trim()
            : status?.userImage?.trim()) ??
        '';
    return SizedBox(
      width: 108,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: image.isNotEmpty
                  ? Image.network(image, fit: BoxFit.cover)
                  : Container(
                      color: scheme.primaryContainer,
                      child: Icon(Icons.person_outline_rounded, color: scheme.primary, size: 34),
                    ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(.72)],
                ),
              ),
            ),
            PositionedDirectional(
              top: 8,
              start: 8,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).scaffoldBackgroundColor,
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundImage: image.isEmpty ? null : NetworkImage(image),
                  child: image.isEmpty ? const Icon(Icons.person_outline_rounded, size: 18) : null,
                ),
              ),
            ),
            PositionedDirectional(
              bottom: 8,
              start: 9,
              end: 8,
              child: Text(
                status == null ? 'إضافة حالة' : 'حالتي',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
              ),
            ),
            PositionedDirectional(
              top: 7,
              end: 7,
              child: Container(
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.status, required this.onTap});

  final UserStatusModel status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = status.userImage?.trim() ?? '';
    final borderColor = status.isViewed
        ? Theme.of(context).dividerColor
        : Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 112,
        height: 160,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image.isNotEmpty)
                Image.network(
                  image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                )
              else
                Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Center(
                    child: Text(
                      status.userName.characters.first,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(.78),
                    ],
                  ),
                ),
              ),
              PositionedDirectional(
                top: 8,
                start: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).scaffoldBackgroundColor,
                    border: Border.all(color: borderColor, width: 2.5),
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundImage:
                        image.isEmpty ? null : NetworkImage(image),
                    child: image.isEmpty
                        ? Text(status.userName.characters.first)
                        : null,
                  ),
                ),
              ),
              PositionedDirectional(
                bottom: 10,
                start: 10,
                end: 10,
                child: Text(
                  status.userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
