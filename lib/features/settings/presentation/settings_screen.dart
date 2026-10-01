import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/premium_ui.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.onThemeModeChanged,
    required this.onSignOut,
    super.key,
  });

  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback onSignOut;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _notificationsKey = 'settings.notifications';
  static const _readReceiptsKey = 'settings.readReceipts';
  static const _typingKey = 'settings.typing';
  static const _onlineKey = 'settings.online';
  static const _themeKey = 'settings.theme';

  bool _notifications = true;
  bool _readReceipts = true;
  bool _typing = true;
  bool _online = true;
  ThemeMode _themeMode = ThemeMode.system;
  bool _loading = true;

  User? get _user => Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_themeKey) ?? 'system';
    if (!mounted) return;
    setState(() {
      _notifications = prefs.getBool(_notificationsKey) ?? true;
      _readReceipts = prefs.getBool(_readReceiptsKey) ?? true;
      _typing = prefs.getBool(_typingKey) ?? true;
      _online = prefs.getBool(_onlineKey) ?? true;
      _themeMode = mode == 'light'
          ? ThemeMode.light
          : mode == 'dark'
              ? ThemeMode.dark
              : ThemeMode.system;
      _loading = false;
    });
    widget.onThemeModeChanged(_themeMode);
  }

  Future<void> _toggle(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    if (!mounted) return;
    setState(() {
      if (key == _notificationsKey) _notifications = value;
      if (key == _readReceiptsKey) _readReceipts = value;
      if (key == _typingKey) _typing = value;
      if (key == _onlineKey) _online = value;
    });
  }

  Future<void> _privacy(String field, bool value) async {
    final user = _user;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {field: value, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (_) {
      if (mounted) _snack('تعذر حفظ إعداد الخصوصية.');
    }
  }

  Future<void> _themePicker() async {
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('اختيار المظهر', style: TextStyle(fontWeight: FontWeight.w900))),
            _themeOption(ThemeMode.system, 'حسب الجهاز', Icons.brightness_auto_rounded),
            _themeOption(ThemeMode.light, 'فاتح', Icons.light_mode_rounded),
            _themeOption(ThemeMode.dark, 'داكن', Icons.dark_mode_rounded),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (selected == null) return;
    final prefs = await SharedPreferences.getInstance();
    final value = selected == ThemeMode.light
        ? 'light'
        : selected == ThemeMode.dark
            ? 'dark'
            : 'system';
    await prefs.setString(_themeKey, value);
    if (!mounted) return;
    setState(() => _themeMode = selected);
    widget.onThemeModeChanged(selected);
  }

  Widget _themeOption(ThemeMode mode, String title, IconData icon) => ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: Radio<ThemeMode>(
          value: mode,
          groupValue: _themeMode,
          onChanged: (_) => Navigator.pop(context, mode),
        ),
        onTap: () => Navigator.pop(context, mode),
      );

  Future<void> _editProfile() async {
    final user = _user;
    if (user == null) {
      _snack('الحساب في وضع التجهيز. سيظهر الملف عند اكتمال الاتصال.');
      return;
    }

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data() ?? {};
    final name = TextEditingController(text: data['displayName']?.toString() ?? user.displayName ?? '');
    final publicId = data['publicId']?.toString() ?? data['username']?.toString() ?? 'memo_${user.uid.substring(0, 8).toLowerCase()}';

    if (!mounted) return;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل الحساب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, textDirection: TextDirection.rtl, decoration: const InputDecoration(labelText: 'الاسم')),
            const SizedBox(height: 12),
            Text('معرّفك العام: @$publicId', style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, name.text.trim()), child: const Text('حفظ')),
        ],
      ),
    );
    name.dispose();
     
    if (result == null) return;

    try {
      final displayName = result.isEmpty ? 'مستخدم MemoChat' : result;
      await user.updateDisplayName(displayName);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'displayName': displayName,
          'username': publicId, 'publicId': publicId,
          'photoUrl': user.photoURL ?? '',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) _snack('تعذر حفظ بيانات الحساب.');
    }
  }

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('سيتم إنهاء جلسة MemoChat الحالية، ويمكنك تسجيل الدخول مجددًا من شاشة الدخول.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('متابعة')),
        ],
      ),
    );
    if (ok == true) widget.onSignOut();
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final user = _user;
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
        children: [
          PremiumHero(
            icon: AppIcons.settings,
            title: 'تحكم كامل',
            subtitle: 'خصص الخصوصية، الإشعارات والمظهر بما يناسبك.',
            action: const SizedBox.shrink(),
          ),
          const SizedBox(height: 14),
          _AccountCard(user: user, onTap: _editProfile),
          const SizedBox(height: 18),
          const _SectionTitle('الإشعارات والخصوصية'),
          _CardGroup(
            children: [
              _SwitchRow(
                icon: AppIcons.notifications,
                title: 'الإشعارات',
                subtitle: 'الرسائل والمكالمات والتنبيهات',
                value: _notifications,
                onChanged: (v) => _toggle(_notificationsKey, v),
              ),
              _SwitchRow(
                icon: AppIcons.message,
                title: 'إيصالات القراءة',
                subtitle: 'السماح بإظهار حالة القراءة',
                value: _readReceipts,
                onChanged: (v) async {
                  await _toggle(_readReceiptsKey, v);
                  await _privacy('readReceipts', v);
                },
              ),
              _SwitchRow(
                icon: AppIcons.profile,
                title: 'مؤشر الكتابة',
                subtitle: 'إظهار أنك تكتب للطرف الآخر',
                value: _typing,
                onChanged: (v) async {
                  await _toggle(_typingKey, v);
                  await _privacy('showTyping', v);
                },
              ),
              _SwitchRow(
                icon: AppIcons.contacts,
                title: 'حالة الاتصال',
                subtitle: 'متصل الآن وآخر ظهور',
                value: _online,
                onChanged: (v) async {
                  await _toggle(_onlineKey, v);
                  await _privacy('showOnline', v);
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _SectionTitle('المظهر والتطبيق'),
          _CardGroup(
            children: [
              ListTile(
                leading: const PremiumIconTile(icon: AppIcons.settings, size: 42, iconSize: 20),
                title: const Text('المظهر', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(_themeMode == ThemeMode.light ? 'فاتح' : _themeMode == ThemeMode.dark ? 'داكن' : 'حسب الجهاز'),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: _themePicker,
              ),
              ListTile(
                leading: const PremiumIconTile(icon: AppIcons.file, size: 42, iconSize: 20),
                title: const Text('البيانات والتخزين', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('إعدادات محلية بدون حذف المحادثات السحابية'),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: () => _snack('التخزين المحلي متاح تلقائيًا ويُدار حسب حاجة التطبيق.'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _SectionTitle('الحساب'),
          _CardGroup(
            children: [
              ListTile(
                leading: const PremiumIconTile(icon: AppIcons.profile, size: 42, iconSize: 20),
                title: Text(user?.displayName ?? 'مستخدم MemoChat', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(user?.isAnonymous == true ? 'حساب مؤقت' : user?.email ?? 'حساب MemoChat'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: _editProfile,
              ),
              ListTile(
                leading: const PremiumIconTile(icon: AppIcons.more, size: 42, iconSize: 20),
                title: const Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('إنهاء الجلسة الحالية'),
                onTap: _confirmSignOut,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.user, required this.onTap});
  final User? user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 31,
                  backgroundImage: user?.photoURL?.isNotEmpty == true ? NetworkImage(user!.photoURL!) : null,
                  child: user?.photoURL?.isNotEmpty == true ? null : const Icon(Icons.person_rounded, size: 28),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.displayName ?? 'مستخدم MemoChat', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                      const SizedBox(height: 4),
                      if (user != null) FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        future: FirebaseFirestore.instance.collection('users').doc(user?.uid ?? '').get(),
                        builder: (context, snapshot) {
                          final data = snapshot.data?.data() ?? const <String, dynamic>{};
                          final id = data['publicId']?.toString() ?? data['username']?.toString() ?? 'memo_${user.uid.substring(0, 8).toLowerCase()}';
                          return Text('@$id', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700));
                        },
                      ),
                      const SizedBox(height: 2),
                      Text(user?.email ?? 'حساب MemoChat'),
                    ],
                  ),
                ),
                const Icon(Icons.edit_outlined),
              ],
            ),
          ),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
      );
}

class _CardGroup extends StatelessWidget {
  const _CardGroup({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final AppIconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        secondary: PremiumIconTile(icon: icon, size: 42, iconSize: 20),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      );
}
