import 'package:flutter/material.dart';
import '../../../core/models/conversation.dart';
import '../../../core/repositories/chat_repository.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/premium_ui.dart';
import 'chat_room_screen.dart';
import '../../shake/presentation/shake_screen.dart';
import '../services/status_service.dart';
import '../presentation/story_viewer_screen.dart';
import '../presentation/add_status_screen.dart';

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
  late final Stream<List<Conversation>> _conversationsStream;

  @override
  void initState() {
    super.initState();
    _conversationsStream = widget.repository.watchConversations();
  }

  @override
  void dispose() { _search.dispose(); _searchFocus.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('المحادثات', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
              tooltip: 'رجّ للتعارف',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShakeScreen(repository: widget.repository))),
              icon: const Icon(Icons.vibration_rounded),
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
            if (snapshot.hasError) {
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
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final conversations = snapshot.data!;
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

  List<Conversation> _filtered(List<Conversation> source) {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return source;
    return source.where((item) {
      final name = item.participant.displayName.toLowerCase();
      final text = item.lastMessage?.text.toLowerCase() ?? '';
      return name.contains(query) || text.contains(query);
    }).toList();
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({required this.conversation, required this.onTap});
  final Conversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = conversation.participant;
    final preview = conversation.lastMessage?.text ?? 'ابدأ المحادثة الآن';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
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
                Icon(Icons.chevron_left_rounded, color: scheme.onSurfaceVariant),
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
  @override Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: SizedBox(width: 72, child: Column(children: [
      Container(width: 62, height: 62, decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.primaryContainer), child: Icon(Icons.add_rounded, color: Theme.of(context).colorScheme.primary, size: 30)),
      const SizedBox(height: 6), const Text('حالتي', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
    ]),
  );
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
        const SizedBox(height: 6), Text(status.userName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}
