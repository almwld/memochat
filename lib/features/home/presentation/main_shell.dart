import 'package:flutter/material.dart';
import '../../../core/repositories/chat_repository.dart';
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
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'المحادثات',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'تواصل',
          ),
          NavigationDestination(
            icon: Icon(Icons.call_outlined),
            selectedIcon: Icon(Icons.call_rounded),
            label: 'المكالمات',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }
}
