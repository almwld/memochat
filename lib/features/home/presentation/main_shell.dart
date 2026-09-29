import 'package:flutter/material.dart';
import '../../../core/repositories/chat_repository.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/premium_ui.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../calls/presentation/calls_history_screen.dart';
import '../../contacts/presentation/contacts_screen.dart';
import '../../settings/presentation/settings_screen.dart';

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
      ChatScreen(repository: widget.repository),
      const ContactsScreen(),
      const CallsHistoryScreen(),
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
