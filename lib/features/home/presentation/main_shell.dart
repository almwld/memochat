import 'package:flutter/material.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../../core/notifications/notification_preferences.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _destinations = <NavigationDestination>[
    NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'المحادثات'),
    NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'تواصل'),
    NavigationDestination(icon: Icon(Icons.call_outlined), selectedIcon: Icon(Icons.call), label: 'المكالمات'),
    NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'الإعدادات'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const ChatScreen(initialTab: 0, showSections: false),
      const ChatScreen(initialTab: 2, showSections: false),
      const ChatScreen(initialTab: 1, showSections: false),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: _destinations,
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _preferences = NotificationPreferences();
  late Future<List<bool>> _values;

  @override
  void initState() {
    super.initState();
    _values = _readValues();
  }

  Future<List<bool>> _readValues() async => [
        await _preferences.messageSounds,
        await _preferences.messageVibration,
        await _preferences.callSounds,
        await _preferences.callVibration,
        await _preferences.callNotifications,
        await _preferences.messageNotifications,
      ];

  Future<void> _set(int index, bool value) async {
    switch (index) {
      case 0: await _preferences.setMessageSounds(value);
      case 1: await _preferences.setMessageVibration(value);
      case 2: await _preferences.setCallSounds(value);
      case 3: await _preferences.setCallVibration(value);
      case 4: await _preferences.setCallNotifications(value);
      case 5: await _preferences.setMessageNotifications(value);
    }
    if (mounted) setState(() => _values = _readValues());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('الإعدادات')),
        body: FutureBuilder<List<bool>>(
          future: _values,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final labels = ['أصوات الرسائل', 'اهتزاز الرسائل', 'نغمة المكالمات', 'اهتزاز المكالمات', 'إشعارات المكالمات', 'إشعارات الرسائل'];
            final icons = [Icons.volume_up_outlined, Icons.vibration, Icons.ring_volume_outlined, Icons.vibration, Icons.call_outlined, Icons.notifications_outlined];
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Text('التنبيهات', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Card(
                  child: Column(children: [
                    for (var i = 0; i < labels.length; i++)
                      SwitchListTile.adaptive(
                        secondary: Icon(icons[i]), title: Text(labels[i]), value: snapshot.data![i], onChanged: (value) => _set(i, value),
                      ),
                  ]),
                ),
                const SizedBox(height: 20),
                Text('حول التطبيق', style: Theme.of(context).textTheme.titleLarge),
                const ListTile(leading: Icon(Icons.info_outline), title: Text('MemoChat'), subtitle: Text('مراسلة واتصال آمن عبر Firebase وLiveKit')),
              ],
            );
          },
        ),
      );
}
