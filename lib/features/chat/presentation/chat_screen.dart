import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/conversation.dart';
import '../../../core/repositories/chat_repository.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/notifications/notification_inbox.dart';
import '../../../core/widgets/premium_ui.dart';
import 'chat_room_screen.dart';
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
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          chatId: createdId,
          otherUserId: '',
          otherUserName: groupName?.isNotEmpty == true ? groupName! : 'مجموعة',
          otherUserImage: data['groupPhoto']?.toString(),
          isGroup: true,
        ),
      ));
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
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatRoomScreen(chatId: id, otherUserId: other, otherUserName: data['groupName']?.toString() ?? 'مجموعة', isGroup: true)));
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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('المحادثات', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            FutureBuilder<int>(
              future: _unreadNotifications,
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return IconButton(
                  tooltip: 'الإشعارات${count > 0 ? ' ($count)' : ''}',
                  onPressed: _openNotifications,
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.notifications_outlined),
                      if (count > 0)
                        PositionedDirectional(
                          top: -5,
                          end: -6,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              count > 99 ? '99+' : '$count',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Theme.of(context).colorScheme.onError, fontSize: 9, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            IconButton(
              tooltip: 'رجّ للتعارف',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShakeScreen(repository: widget.repository))),
              icon: const Icon(Icons.vibration_rounded),
            ),
            IconButton(
              tooltip: 'مجموعة جديدة',
              onPressed: _openCreateGroup,
              icon: const Icon(Icons.group_add_outlined),
            ),
            IconButton(
              tooltip: 'بحث',
              onPressed: () => _searchFocus.requestFocus(),
              icon: const AppIcon(AppIcons.search, size: 23),
            ),
          ],
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
            if (snapshot.hasError && _lastConversations.isEmpty) {
              return _StateView(
                icon: AppIcons.chat,
                title: 'تعذر تحميل المحادثات',
                subtitle: 'تحقق من الاتصال ثم حاول مرة أخرى.',
                action: FilledButton.icon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة'),
                ),
              );
            }
            if (!snapshot.hasData && _lastConversations.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            final conversations = snapshot.data ?? _lastConversations;
            final filtered = _filtered(conversations);
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: PremiumHero(
                      icon: AppIcons.chat,
                      title: 'مساحتك الخاصة',
                      subtitle: 'كل محادثاتك ورسائلك في مكان واحد، بتجربة عربية سريعة ومرتبة.',
                      action: IconButton(
                        tooltip: 'محادثة جديدة',
                        onPressed: widget.onNewChat,
                        color: Colors.white,
                        icon: const Icon(Icons.add_rounded),
                      ),
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
                        return SizedBox(
                          height: 104,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: statuses.length + 1,
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return _StatusAddTile(onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddStatusScreen())));
                              }
                              final status = statuses[index - 1];
                              return _StatusTile(
                                status: status,
                                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StoryViewerScreen(status: status))),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'ابحث في المحادثات...',
                        prefixIcon: AppIcon(AppIcons.search, size: 21),
                      ),
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
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatRoomScreen(
                                chatId: item.id,
                                otherUserId: item.participant.id,
                                otherUserName: item.participant.displayName,
                                otherUserImage: item.participant.avatarUrl,
                              ),
                            ),
                          ),
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

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({required this.conversation, required this.onTap, required this.onMarkUnread, required this.onArchive, required this.onFolder});
  final Conversation conversation;
  final VoidCallback onTap;
  final Future<void> Function() onMarkUnread;
  final Future<void> Function() onArchive;
  final VoidCallback onFolder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = conversation.participant;
    final preview = conversation.lastMessage?.text ?? 'ابدأ المحادثة الآن';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        onLongPress: onMarkUnread,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 10, 10),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 29,
                    backgroundColor: scheme.primaryContainer,
                    backgroundImage: user.avatarUrl?.isNotEmpty == true ? NetworkImage(user.avatarUrl!) : null,
                    child: user.avatarUrl?.isNotEmpty == true
                        ? null
                        : Text(
                            user.displayName.characters.first,
                            style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w900, fontSize: 19),
                          ),
                  ),
                  if (user.isOnline)
                    PositionedDirectional(
                      bottom: 1,
                      end: 1,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF28B86B),
                          shape: BoxShape.circle,
                          border: Border.all(color: Theme.of(context).cardColor, width: 2.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (conversation.unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    conversation.unreadCount.toString(),
                    style: TextStyle(color: scheme.onPrimary, fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                )
              else
                PopupMenuButton<String>(
                  onSelected: (value) { if (value == 'archive') onArchive(); if (value == 'folder') onFolder(); },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'archive', child: Text(conversation.isArchived ? 'إلغاء الأرشفة' : 'أرشفة')),
                    const PopupMenuItem(value: 'folder', child: Text('مجلد')),
                  ],
                  icon: Icon(Icons.more_horiz_rounded, color: scheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
    );
  }
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
  const _StatusAddTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primaryContainer,
              ),
              child: Icon(Icons.add_rounded, color: scheme.primary, size: 30),
            ),
            const SizedBox(height: 6),
            const Text(
              'حالتي',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
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
  @override Widget build(BuildContext context) {
    final image = status.userImage?.trim() ?? '';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(width: 72, child: Column(children: [
        Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2)), child: CircleAvatar(radius: 29, backgroundImage: image.isEmpty ? null : NetworkImage(image), child: image.isEmpty ? Text(status.userName.characters.first) : null)),
        const SizedBox(height: 6),
        Text(
          status.userName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ]),
    ),
  );
  }
}
