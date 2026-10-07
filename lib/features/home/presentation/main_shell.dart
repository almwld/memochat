import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../core/repositories/chat_repository.dart';
import '../../../core/models/conversation.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/premium_ui.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../contacts/presentation/contacts_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../shake/presentation/shake_screen.dart';
import '../../advanced/presentation/advanced_hub_screen.dart';
import '../../games/presentation/games_hub_screen.dart';
import '../../social/presentation/social_screen.dart';
import '../../../core/services/quick_action_service.dart';
import '../../profile/presentation/profile_screen.dart';

class _ChatNavIcon extends StatelessWidget {
  const _ChatNavIcon({required this.count, required this.selected});

  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final icon = selected
        ? const PremiumIconTile(icon: AppIcons.chat, size: 42, iconSize: 21)
        : const AppIcon(AppIcons.chat, size: 22);
    if (count <= 0) return icon;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        PositionedDirectional(
          top: selected ? -2 : -7,
          end: selected ? -4 : -7,
          child: Container(
            constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context).colorScheme.surface,
                width: 1.5,
              ),
            ),
            child: Text(
              count > 99 ? '99+' : '$count',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onError,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({
    required this.repository,
    required this.onThemeModeChanged,
    required this.onSignOut,
    super.key,
  });

  final ChatRepository repository;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback onSignOut;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _index = 0;
  bool _navVisible = true;
  late final List<Widget> _pages;
  late final Stream<List<Conversation>> _conversationsStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _conversationsStream = widget.repository.watchConversations();
    _pages = [
      ChatScreen(repository: widget.repository, onNewChat: () => setState(() => _index = 1)),
      ContactsScreen(repository: widget.repository),
      const SocialScreen(),
      DiscoverScreen(repository: widget.repository),
      SettingsScreen(onThemeModeChanged: widget.onThemeModeChanged, onSignOut: widget.onSignOut),
    ];
    _consumeQuickAction();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _consumeQuickAction();
  }

  Future<void> _consumeQuickAction() async {
    final action = await QuickActionService.consume();
    if (!mounted || action == null) return;
    final nextIndex = switch (action) {
      'chat' || 'compose' => 0,
      'contacts' => 1,
      'social' => 2,
      _ => null,
    };
    if (nextIndex != null && nextIndex != _index) {
      setState(() => _index = nextIndex);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _handleNavigationScroll(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final nextVisible = notification.metrics.pixels <= 0 ||
        notification.direction == ScrollDirection.forward;
    if (nextVisible != _navVisible && mounted) {
      setState(() => _navVisible = nextVisible);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: NotificationListener<UserScrollNotification>(
        onNotification: _handleNavigationScroll,
        child: IndexedStack(index: _index, children: _pages),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: AnimatedSlide(
          offset: _navVisible ? Offset.zero : const Offset(0, 1.15),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: _navVisible ? 1 : 0,
            duration: const Duration(milliseconds: 160),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: NavigationBar(
                  height: 72,
                  selectedIndex: _index,
                  onDestinationSelected: (index) => setState(() => _index = index),
                  destinations: [
              NavigationDestination(
                icon: StreamBuilder<List<Conversation>>(
                  stream: _conversationsStream,
                  builder: (context, snapshot) {
                    final count = snapshot.data?.fold<int>(
                          0,
                          (sum, conversation) =>
                              sum + conversation.unreadCount,
                        ) ??
                        0;
                    return _ChatNavIcon(
                      count: count,
                      selected: false,
                    );
                  },
                ),
                selectedIcon: StreamBuilder<List<Conversation>>(
                  stream: _conversationsStream,
                  builder: (context, snapshot) {
                    final count = snapshot.data?.fold<int>(
                          0,
                          (sum, conversation) =>
                              sum + conversation.unreadCount,
                        ) ??
                        0;
                    return _ChatNavIcon(
                      count: count,
                      selected: true,
                    );
                  },
                ),
                label: 'المحادثات',
              ),
              NavigationDestination(
                icon: AppIcon(AppIcons.contacts, size: 22),
                selectedIcon: PremiumIconTile(
                  icon: AppIcons.contacts,
                  size: 42,
                  iconSize: 21,
                ),
                label: 'تواصل',
              ),
              NavigationDestination(
                icon: Icon(Icons.dynamic_feed_outlined, size: 22),
                selectedIcon: Icon(Icons.dynamic_feed_rounded, size: 28),
                label: 'Memo',
              ),
              NavigationDestination(
                icon: AppIcon(AppIcons.search, size: 22),
                selectedIcon: PremiumIconTile(
                  icon: AppIcons.search,
                  size: 42,
                  iconSize: 21,
                ),
                label: 'اكتشف',
              ),
              NavigationDestination(
                icon: AppIcon(AppIcons.settings, size: 22),
                selectedIcon: PremiumIconTile(
                  icon: AppIcons.settings,
                  size: 42,
                  iconSize: 21,
                ),
                label: 'الإعدادات',
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
}


class _ProfileEntryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        ),
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(radius: 25, child: Icon(Icons.person_rounded)),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ملفي الشخصي', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    SizedBox(height: 3),
                    Text('الهوية، النبذة، الإحصائيات والخصوصية'),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({required this.repository, super.key});

  final ChatRepository repository;

  @override
  Widget build(BuildContext context) {
    return ScrollAwareScaffold(
      appBar: AppBar(
        title: const Text('اكتشف', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        children: [
          const MemoPageHeader(
            title: 'اكتشف',
            subtitle: 'أشخاص وطرق جديدة للتواصل، بنفس تجربة MemoChat الموحدة.',
            icon: Icons.search,
          ),
          const SizedBox(height: 8),
          _ProfileEntryCard(),
          const MemoSectionLabel('التواصل'),
          MemoListCard(
            icon: Icons.person_search_rounded,
            title: 'العثور على أشخاص',
            subtitle: 'ابحث بالاسم أو المعرّف العام وابدأ محادثة.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ContactsScreen(repository: repository)),
            ),
          ),
          const SizedBox(height: 8),
          MemoListCard(
            icon: Icons.sync_alt_rounded,
            title: 'رجّ للتعارف',
            subtitle: 'اعثر على شخص آخر يهز هاتفه في الوقت نفسه.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ShakeScreen(repository: repository)),
            ),
          ),
          const MemoSectionLabel('مساحات MemoChat'),
          MemoListCard(
            icon: Icons.auto_awesome_outlined,
            title: 'المزايا المتقدمة',
            subtitle: 'غرف صوتية، Mini Apps، وملفات Business.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdvancedHubScreen()),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GamesHubScreen()),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 10, 12),
                child: Row(
                  children: [
                    PremiumIconTile(
                      icon: AppIcons.chat,
                      size: 46,
                      iconSize: 23,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ألعاب MemoChat',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                          SizedBox(height: 3),
                          Text('تحديات حقيقية بنقاط ومستويات ونتائج شخصية.',
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_left_rounded),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
