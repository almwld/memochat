import 'package:flutter/material.dart';
import '../../../core/repositories/chat_repository.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/premium_ui.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../chat/presentation/calls_screen.dart';
import '../../contacts/presentation/contacts_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../shake/presentation/shake_screen.dart';

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

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      ChatScreen(
        repository: widget.repository,
        onNewChat: () => setState(() => _index = 1),
      ),
      ContactsScreen(repository: widget.repository),
      DiscoverScreen(repository: widget.repository),
      const CallsScreen(),
      SettingsScreen(
        onThemeModeChanged: widget.onThemeModeChanged,
        onSignOut: widget.onSignOut,
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: pages),
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
