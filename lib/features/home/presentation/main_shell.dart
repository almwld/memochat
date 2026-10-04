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
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      ChatScreen(repository: widget.repository, onNewChat: () => setState(() => _index = 1)),
      ContactsScreen(repository: widget.repository),
      const SocialScreen(),
      DiscoverScreen(repository: widget.repository),
      const CallsScreen(),
      SettingsScreen(onThemeModeChanged: widget.onThemeModeChanged, onSignOut: widget.onSignOut),
    ];
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
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GamesHubScreen())),
              child: Container(
                decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0A8F83), Color(0xFF164C72)], begin: AlignmentDirectional.topStart, end: AlignmentDirectional.bottomEnd)),
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
