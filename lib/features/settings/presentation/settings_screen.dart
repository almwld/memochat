import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  bool _notifications = true;
  bool _readReceipts = true;
  bool _typing = true;
  bool _online = true;
  ThemeMode _themeMode = ThemeMode.system;
  bool _loading = true;

  User? get _user =>
      Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notifications = prefs.getBool(_notificationsKey) ?? true;
      _readReceipts = prefs.getBool(_readReceiptsKey) ?? true;
      _typing = prefs.getBool(_typingKey) ?? true;
      _online = prefs.getBool(_onlineKey) ?? true;
      final mode = prefs.getString('settings.theme') ?? 'system';
      _themeMode = switch (mode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      _loading = false;
    });
    widget.onThemeModeChanged(_themeMode);
  }

  Future<void> _setBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    if (mounted) setState(() {});
  }

  Future<void> _setTheme(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'settings.theme',
      switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      },
    );
    if (!mounted) return;
    setState(() => _themeMode = mode);
    widget.onThemeModeChanged(mode);
  }

  Future<void> _updatePrivacy(String field, bool value) async {
    final user = _user;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {field: value, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ إعداد الخصوصية')),
        );
      }
    }
  }

  Future<void> _editProfile() async {
    final user = _user;
    if (user == null) {
      _showInfo('الحساب غير متصل بخدمة Firebase حاليًا.');
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = doc.data() ?? {};
    final nameController = TextEditingController(
      text: data['displayName']?.toString() ?? user.displayName ?? '',
    );
    final usernameController = TextEditingController(
      text: data['username']?.toString() ?? '',
    );

    if (!mounted) return;
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل الحساب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              textDirection: TextDirection.rtl,
              decoration: const InputDecoration(
                labelText: 'الاسم',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: usernameController,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'اسم المستخدم',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              (nameController.text.trim(), usernameController.text.trim()),
            ),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    nameController.dispose();
    usernameController.dispose();

    if (result == null) return;
    try {
      await user.updateDisplayName(
        result.$1.isEmpty ? 'مستخدم MemoChat' : result.$1,
      );
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'displayName':
              result.$1.isEmpty ? 'مستخدم MemoChat' : result.$1,
          'username': result.$2.replaceFirst('@', '').trim().toLowerCase(),
          'photoUrl': user.photoURL ?? '',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        _showInfo('تعذر حفظ بيانات الحساب. تحقق من الاتصال وقواعد Firestore.');
      }
    }
  }

  Future<void> _showThemePicker() async {
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('المظهر'),
        children: [
          _themeOption(context, ThemeMode.system, 'حسب الجهاز'),
          _themeOption(context, ThemeMode.light, 'فاتح'),
          _themeOption(context, ThemeMode.dark, 'داكن'),
        ],
      ),
    );
    if (selected != null) await _setTheme(selected);
  }

  Widget _themeOption(BuildContext context, ThemeMode mode, String title) =>
      RadioListTile<ThemeMode>(
        value: mode,
        groupValue: _themeMode,
        title: Text(title),
        onChanged: (value) {
          if (value != null) Navigator.pop(context, value);
        },
      );

  Future<void> _clearLocalSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مسح الإعدادات المحلية؟'),
        content: const Text(
          'سيتم إعادة إعدادات MemoChat المحلية إلى قيمها الافتراضية. '
          'لن يتم حذف المحادثات أو بيانات Firebase.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('مسح'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_notificationsKey);
    await prefs.remove(_readReceiptsKey);
    await prefs.remove(_typingKey);
    await prefs.remove(_onlineKey);
    await prefs.remove('settings.theme');
    if (!mounted) return;
    setState(() {
      _notifications = true;
      _readReceipts = true;
      _typing = true;
      _online = true;
      _themeMode = ThemeMode.system;
    });
    widget.onThemeModeChanged(ThemeMode.system);
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('سيتم إنهاء جلسة الحساب الحالية ثم إنشاء جلسة مؤقتة جديدة.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onSignOut();
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        appBar: _SettingsAppBar(),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = _user;
    return Scaffold(
      appBar: const _SettingsAppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _AccountCard(user: user, onTap: _editProfile),
          const SizedBox(height: 16),
          const _SectionTitle('التفضيلات'),
          _SettingsCard(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.notifications_outlined),
                title: const Text('الإشعارات'),
                subtitle: const Text('رسائل ومكالمات وتنبيهات النظام'),
                value: _notifications,
                onChanged: (value) async {
                  setState(() => _notifications = value);
                  await _setBool(_notificationsKey, value);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.done_all_rounded),
                title: const Text('إيصالات القراءة'),
                subtitle: const Text('السماح بإظهار حالة قراءة الرسائل'),
                value: _readReceipts,
                onChanged: (value) async {
                  setState(() => _readReceipts = value);
                  await _setBool(_readReceiptsKey, value);
                  await _updatePrivacy('readReceipts', value);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.edit_note_rounded),
                title: const Text('مؤشر الكتابة'),
                subtitle: const Text('إظهار أنك تكتب للطرف الآخر'),
                value: _typing,
                onChanged: (value) async {
                  setState(() => _typing = value);
                  await _setBool(_typingKey, value);
                  await _updatePrivacy('showTyping', value);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.circle_outlined),
                title: const Text('حالة الاتصال'),
                subtitle: const Text('إظهار متصل الآن وآخر ظهور'),
                value: _online,
                onChanged: (value) async {
                  setState(() => _online = value);
                  await _setBool(_onlineKey, value);
                  await _updatePrivacy('showOnline', value);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _SectionTitle('المظهر والبيانات'),
          _SettingsCard(
            children: [
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('المظهر'),
                subtitle: Text(
                  switch (_themeMode) {
                    ThemeMode.light => 'فاتح',
                    ThemeMode.dark => 'داكن',
                    ThemeMode.system => 'حسب الجهاز',
                  },
                ),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: _showThemePicker,
              ),
              ListTile(
                leading: const Icon(Icons.storage_outlined),
                title: const Text('البيانات والتخزين'),
                subtitle: const Text('إعادة الإعدادات المحلية دون حذف بيانات السحابة'),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: _clearLocalSettings,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _SectionTitle('الحساب'),
          _SettingsCard(
            children: [
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('تسجيل الخروج'),
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

class _SettingsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _SettingsAppBar();

  @override
  Widget build(BuildContext context) =>
      AppBar(title: const Text('الإعدادات'));

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.user, required this.onTap});

  final User? user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          contentPadding:
              const EdgeInsetsDirectional.fromSTEB(16, 10, 12, 10),
          leading: CircleAvatar(
            radius: 28,
            backgroundImage: user?.photoURL?.isNotEmpty == true
                ? NetworkImage(user!.photoURL!)
                : null,
            child: user?.photoURL?.isNotEmpty == true
                ? null
                : const Icon(Icons.person_rounded),
          ),
          title: Text(
            user?.displayName ?? 'مستخدم MemoChat',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            user?.isAnonymous == true
                ? 'حساب مؤقت — اضغط للتعديل'
                : user?.email ?? 'حساب MemoChat',
          ),
          trailing: const Icon(Icons.edit_outlined),
          onTap: onTap,
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );
}
