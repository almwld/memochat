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
  const MainShell({required this.repository, required this.onThemeModeChanged, required this.onSignOut, super.key});
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
      ChatScreen(repository: widget.repository, onNewChat: () => setState(() => _index = 1)),
      ContactsScreen(repository: widget.repository),
      DiscoverScreen(repository: widget.repository),
      const CallsScreen(),
      SettingsScreen(onThemeModeChanged: widget.onThemeModeChanged, onSignOut: widget.onSignOut),
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
                selectedIcon: PremiumIconTile(icon: AppIcons.chat, size: 42, iconSize: 21),
                label: 'المحادثات',
              ),
              NavigationDestination(
                icon: AppIcon(AppIcons.contacts, size: 22),
                selectedIcon: PremiumIconTile(icon: AppIcons.contacts, size: 42, iconSize: 21),
                label: 'تواصل',
              ),
              NavigationDestination(
                icon: Icon(Icons.auto_awesome_rounded, size: 22),
                selectedIcon: Icon(Icons.auto_awesome_rounded, size: 28),
                label: 'اكتشف',
              ),
              NavigationDestination(
                icon: AppIcon(AppIcons.phoneCall, size: 22),
                selectedIcon: PremiumIconTile(icon: AppIcons.phoneCall, size: 42, iconSize: 21),
                label: 'المكالمات',
              ),
              NavigationDestination(
                icon: AppIcon(AppIcons.settings, size: 22),
                selectedIcon: PremiumIconTile(icon: AppIcons.settings, size: 42, iconSize: 21),
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

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('اكتشف', style: TextStyle(fontWeight: FontWeight.w900))),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: PremiumHero(
                icon: AppIcons.contacts,
                title: 'عالم MemoChat',
                subtitle: 'اعثر على أشخاص جدد وابدأ طرقاً مختلفة للتواصل، بدون بيانات تجريبية أو نتائج وهمية.',
                action: const SizedBox.shrink(),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
            sliver: SliverList.list(
              children: [
                _DiscoverCard(
                  icon: Icons.vibration_rounded,
                  title: 'رجّ للتعارف',
                  subtitle: 'رجّ هاتفك في نفس اللحظة مع شخص آخر للعثور على تطابق قريب زمنياً.',
                  accent: const Color(0xFFFF3F91),
                  onTap: () => _open(context, ShakeScreen(repository: repository)),
                ),
                const SizedBox(height: 12),
                _DiscoverCard(
                  icon: AppIcons.contacts,
                  title: 'العثور على أشخاص',
                  subtitle: 'ابحث بالاسم أو اسم المستخدم وابدأ محادثة مباشرة.',
                  accent: scheme.primary,
                  onTap: () => _open(context, ContactsScreen(repository: repository)),
                ),
                const SizedBox(height: 12),
                _DiscoverCard(
                  icon: AppIcons.phoneCall,
                  title: 'المكالمات',
                  subtitle: 'انتقل إلى سجل المكالمات وابدأ اتصالاً صوتياً أو مرئياً.',
                  accent: const Color(0xFF6C63FF),
                  onTap: () => _open(context, const CallsScreen()),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: scheme.primary, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'MemoChat مصمم ليتوسع لاحقاً إلى مجتمعات وقنوات وأدوات تفاعلية وخدمات داخل المحادثة. لن تظهر أي ميزة هنا كأنها متاحة قبل أن يكون لها تنفيذ حقيقي.',
                            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverCard extends StatelessWidget {
  const _DiscoverCard({required this.icon, required this.title, required this.subtitle, required this.accent, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(color: accent.withOpacity(.12), borderRadius: BorderRadius.circular(18)),
                child: Icon(icon, color: accent, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_left_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
