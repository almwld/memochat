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
import '../../social/presentation/social_screen.dart';
import '../../../core/services/quick_action_service.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: Padding(
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
    );
  }
}


class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({required this.repository, super.key});

  final ChatRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اكتشف', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        children: [
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
            child: ListTile(
              leading: const PremiumIconTile(icon: AppIcons.phoneCall, size: 48, iconSize: 23),
              title: const Text('المكالمات', style: TextStyle(fontWeight: FontWeight.w900)),
              subtitle: const Text('الوصول السريع إلى سجل المكالمات.'),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CallsScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
