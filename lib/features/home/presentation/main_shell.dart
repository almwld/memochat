import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/repositories/chat_repository.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/premium_ui.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../chat/presentation/calls_screen.dart';
import '../../contacts/presentation/contacts_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../shake/presentation/shake_screen.dart';
import '../../advanced/presentation/advanced_hub_screen.dart';
import '../../games/presentation/games_hub_screen.dart';
import '../../social/presentation/social_screen.dart';
import '../../../core/services/quick_action_service.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../../core/crypto/signal_session_manager.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pages = [
      ChatScreen(repository: widget.repository, onNewChat: () => setState(() => _index = 1)),
      ContactsScreen(repository: widget.repository),
      const SocialScreen(),
      DiscoverScreen(repository: widget.repository),
      const CallsScreen(),
      SettingsScreen(onThemeModeChanged: widget.onThemeModeChanged, onSignOut: widget.onSignOut),
    ];
    _consumeQuickAction();
    unawaited(_prepareE2EE());
  }

  Future<void> _prepareE2EE() async {
    try {
      await SignalSessionManager.instance.ensureReady();
    } catch (_) {
      // Encryption setup must never delay or block the visible UI.
    }
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
      'calls' => 4,
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
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: NavigationBar(
            height: 72,
            selectedIndex: _index,
            onDestinationSelected: (index) => setState(() => _index = index),
            destinations: const [
              NavigationDestination(
                icon: AppIcon(AppIcons.chat, size: 22),
                selectedIcon: PremiumIconTile(
                  icon: AppIcons.chat,
                  size: 42,
                  iconSize: 21,
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
                icon: AppIcon(AppIcons.phoneCall, size: 22),
                selectedIcon: PremiumIconTile(
                  icon: AppIcons.phoneCall,
                  size: 42,
                  iconSize: 21,
                ),
                label: 'المكالمات',
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
          _ProfileEntryCard(),
          const SizedBox(height: 12),
          PremiumHero(
            icon: AppIcons.search,
            title: 'اكتشف أشخاصاً وطرقاً جديدة للتواصل',
            subtitle: 'ابحث عن الأشخاص، ابدأ محادثة، أو استخدم الرجّ للتعارف القريب.',
            action: const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const PremiumIconTile(icon: AppIcons.contacts, size: 48, iconSize: 23),
              title: const Text('العثور على أشخاص', style: TextStyle(fontWeight: FontWeight.w900)),
              subtitle: const Text('ابحث بالاسم أو المعرّف العام وابدأ محادثة.'),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ContactsScreen(repository: repository)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const PremiumIconTile(icon: AppIcons.chat, size: 48, iconSize: 23),
              title: const Text('رجّ للتعارف', style: TextStyle(fontWeight: FontWeight.w900)),
              subtitle: const Text('رجّ هاتفك للعثور على شخص آخر يهز هاتفه في الوقت نفسه.'),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ShakeScreen(repository: repository)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const PremiumIconTile(icon: AppIcons.chat, size: 48, iconSize: 23),
              title: const Text('المزايا المتقدمة', style: TextStyle(fontWeight: FontWeight.w900)),
              subtitle: const Text('غرف صوتية، Mini Apps، وملفات Business.'),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdvancedHubScreen()),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GamesHubScreen())),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0A8F83),
                  border: Border.all(color: Colors.white.withOpacity(.10)),
                ),
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white.withOpacity(.18), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.sports_esports_rounded, color: Colors.white, size: 27)),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('ألعاب MemoChat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                    SizedBox(height: 4),
                    Text('55 تحدياً بنقاط ومستويات ونتائج شخصية.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ])),
                  const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
