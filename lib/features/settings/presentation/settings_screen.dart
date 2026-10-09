import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/premium_ui.dart';
import '../../notifications/presentation/notification_center_screen.dart';
import '../../love_letter/memo_dedication_screen.dart';
import 'advanced_privacy_screen.dart';
import 'vpn_tunnel_screen.dart';
import '../../offline_link/presentation/offline_link_screen.dart';
import '../../../core/security/security_settings_service.dart';
import '../../../core/notifications/notification_preferences.dart';
import '../../profile/presentation/profile_screen.dart';

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
  static const _hideFromContactsKey = 'settings.hideFromContacts';
  static const _themeKey = 'settings.theme';

  bool _notifications = true;
  bool _readReceipts = true;
  bool _typing = true;
  bool _online = true;
  bool _hideFromContacts = false;
  ThemeMode _themeMode = ThemeMode.system;
  bool _loading = true;

  User? get _user => Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _load();
    SecuritySettingsService.instance.load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_themeKey) ?? 'system';
    var hideFromContacts = prefs.getBool(_hideFromContactsKey) ?? false;
    final user = _user;
    if (user != null) {
      try {
        final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        hideFromContacts = snap.data()?['hideFromContacts'] == true;
        await prefs.setBool(_hideFromContactsKey, hideFromContacts);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _notifications = prefs.getBool(_notificationsKey) ?? true;
      _readReceipts = prefs.getBool(_readReceiptsKey) ?? true;
      _typing = prefs.getBool(_typingKey) ?? true;
      _online = prefs.getBool(_onlineKey) ?? true;
      _hideFromContacts = hideFromContacts;
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

  Future<void> _open(String title, IconData icon, List<_SettingItem> items) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => _SettingsSectionScreen(title: title, icon: icon, items: items)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final user = _user;
    return ScrollAwareScaffold(
      appBar: AppBar(title: const Text('الإعدادات', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          _AccountCard(user: user, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()))),
          _Section(title: 'الحساب', children: [
            _Row(Icons.person_outline_rounded, 'الحساب والملف الشخصي', 'الصورة، الاسم، المعرّف العام', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()))),
            _Row(Icons.lock_outline_rounded, 'الخصوصية والأمان', 'آخر ظهور، القراءة، الحظر والتشفير', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdvancedPrivacyScreen()))),
            _Row(Icons.devices_other_rounded, 'الأجهزة المرتبطة', 'الجلسات والتحقق بخطوتين', () => _open('الأجهزة المرتبطة', Icons.devices_other_rounded, const [
              _SettingItem('التحقق بخطوتين', 'حماية إضافية للحساب', Icons.password_rounded, switchable: true),
              _SettingItem('تنبيهات الأمان', 'التنبيه عند تغير معلومات الأمان', Icons.security_update_good_outlined, switchable: true),
              _SettingItem('الجلسات النشطة', 'الأجهزة التي تستخدم الحساب', Icons.devices_outlined),
            ])),
          ]),
          _Section(title: 'المحادثات', children: [
            _Row(Icons.chat_bubble_outline_rounded, 'المحادثات', 'الخلفية، الخط، الرسائل المؤقتة والوسائط', () => _open('المحادثات', Icons.chat_bubble_outline_rounded, const [
              _SettingItem('الرسائل المؤقتة', 'إخفاء الرسائل تلقائياً', Icons.timer_outlined, switchable: true),
              _SettingItem('حفظ الوسائط', 'حفظ الصور والفيديو في الجهاز', Icons.photo_library_outlined, switchable: true, defaultValue: false),
              _SettingItem('معاينة الروابط', 'عرض معاينة الروابط', Icons.link_rounded, switchable: true),
              _SettingItem('حجم الخط', 'تخصيص حجم النص', Icons.text_fields_rounded),
              _SettingItem('خلفية المحادثة', 'تخصيص خلفية غرف الدردشة', Icons.wallpaper_outlined),
            ])),
            _Row(Icons.archive_outlined, 'المجلدات والأرشيف', 'تنظيم المحادثات المؤرشفة والمجلدات', () => _open('المجلدات والأرشيف', Icons.archive_outlined, const [
              _SettingItem('الإبقاء على المؤرشفة', 'لا تعود المحادثة عند وصول رسالة', Icons.archive_outlined, switchable: true),
              _SettingItem('مجلدات المحادثات', 'إدارة مجلداتك المخصصة', Icons.folder_outlined),
            ])),
          ]),
          _Section(title: 'الإشعارات والأصوات', children: [
            _Row(Icons.notifications_none_rounded, 'الإشعارات', 'الرسائل والمجموعات', () => _open('الإشعارات والأصوات', Icons.notifications_none_rounded, const [
              _SettingItem('إشعارات الرسائل', 'تنبيهات الرسائل الخاصة والمجموعات', Icons.chat_outlined, switchable: true),
              _SettingItem('صوت الإشعارات', 'تشغيل أصوات التنبيه', Icons.volume_up_outlined, switchable: true),
              _SettingItem('الاهتزاز', 'اهتزاز الجهاز مع التنبيهات', Icons.vibration_outlined, switchable: true),
              _SettingItem('إشعارات المكالمات', 'تنبيهات المكالمات الصوتية والمرئية', Icons.call, switchable: true),
              _SettingItem('صوت المكالمات', 'تشغيل نغمة المكالمة الواردة', Icons.volume_up_outlined, switchable: true),
              _SettingItem('اهتزاز المكالمات', 'اهتزاز الجهاز عند ورود مكالمة', Icons.vibration_outlined, switchable: true),
              _SettingItem('الإشعارات الأخرى', 'تنبيهات النظام والدعوات والتفاعلات', Icons.notifications_active_outlined, switchable: true),
              _SettingItem('صوت الإشعارات الأخرى', 'تشغيل الصوت للتنبيهات غير الرسائل والمكالمات', Icons.volume_up_outlined, switchable: true),
              _SettingItem('اهتزاز الإشعارات الأخرى', 'اهتزاز الجهاز للتنبيهات الأخرى', Icons.vibration_outlined, switchable: true),
              _SettingItem('معاينة الرسائل', 'إظهار محتوى الرسالة في الإشعار', Icons.preview_outlined, switchable: true),
            ])),
            _Row(Icons.notifications_active_outlined, 'مركز الإشعارات', 'السجل والإشعارات غير المقروءة', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationCenterScreen()))),
          ]),
          _Section(title: 'البيانات والتخزين', children: [
            _Row(Icons.data_usage_outlined, 'البيانات والتخزين', 'التنزيل التلقائي والمساحة واستخدام الشبكة', () => _open('البيانات والتخزين', Icons.data_usage_outlined, const [
              _SettingItem('التنزيل التلقائي للصور', 'حسب نوع الشبكة', Icons.image_outlined),
              _SettingItem('التنزيل التلقائي للفيديو', 'التحكم في تنزيل الفيديو', Icons.video_library_outlined),
              _SettingItem('التنزيل التلقائي للملفات', 'التحكم في تنزيل المستندات', Icons.insert_drive_file_outlined),
              _SettingItem('التخزين', 'إدارة الوسائط والمساحة المحلية', Icons.storage_outlined),
            ])),
          ]),
          _Section(title: 'القصص والمجموعات', children: [
            _Row(Icons.auto_stories_outlined, 'القصص والحالة', 'الخصوصية والمشاهدات والردود', () => _open('القصص والحالة', Icons.auto_stories_outlined, const [
              _SettingItem('خصوصية الحالة', 'من يمكنه رؤية حالتك', Icons.visibility_outlined),
              _SettingItem('إيصالات مشاهدة الحالة', 'تسجيل مشاهدات الحالة', Icons.done_all_rounded, switchable: true),
              _SettingItem('السماح بالردود', 'السماح بالرد على الحالة', Icons.reply_outlined, switchable: true),
            ])),
            _Row(Icons.groups_outlined, 'المجموعات والمجتمعات', 'الدعوات والإضافة والإشعارات', () => _open('المجموعات والمجتمعات', Icons.groups_outlined, const [
              _SettingItem('من يمكنه إضافتي', 'التحكم في إضافتك للمجموعات', Icons.person_add_alt_1_outlined),
              _SettingItem('إشعارات المجموعات', 'التحكم في تنبيهات المجموعات', Icons.groups_2_outlined, switchable: true),
            ])),
          ]),
          _Section(title: 'المظهر وإمكانية الوصول', children: [
            _Row(Icons.palette_outlined, 'المظهر', _themeMode == ThemeMode.system ? 'حسب الجهاز' : _themeMode == ThemeMode.dark ? 'داكن' : 'فاتح', _themePicker),
            _Row(Icons.accessibility_new_outlined, 'إمكانية الوصول', 'الحركة والتباين وتشغيل الوسائط', () => _open('إمكانية الوصول', Icons.accessibility_new_outlined, const [
              _SettingItem('تقليل الحركة', 'تقليل الانتقالات', Icons.motion_photos_off_outlined, switchable: true),
              _SettingItem('تباين أعلى', 'زيادة وضوح الواجهة', Icons.contrast_outlined, switchable: true),
              _SettingItem('التشغيل التلقائي', 'تشغيل الوسائط تلقائياً', Icons.play_circle_outline_rounded, switchable: true),
            ])),
          ]),
          _Section(title: 'الأمان', children: [
            _Row(Icons.shield_outlined, 'مركز الأمان والتشفير', 'مستوى الحماية والتشفير الفعلي', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdvancedPrivacyScreen()))),
            _Row(Icons.vpn_lock_outlined, 'VPN Tunnel', 'اتصال استثنائي للشبكات المعزولة عند انقطاع الإنترنت', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VpnTunnelScreen()))),
            _Row(Icons.cell_tower_rounded, 'Offline Link', 'مراسلة محلية مشفرة عبر النفق دون Firebase أو إنترنت', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OfflineLinkScreen()))),
          ]),
          _Section(title: 'الدعم', children: [
            _Row(Icons.help_outline_rounded, 'المساعدة', 'مركز المساعدة والإبلاغ', () => _open('المساعدة', Icons.help_outline_rounded, const [
              _SettingItem('مركز المساعدة', 'إرشادات استخدام MemoChat', Icons.menu_book_outlined),
              _SettingItem('الإبلاغ عن مشكلة', 'وصف المشكلة لفريق الدعم', Icons.bug_report_outlined),
              _SettingItem('الشروط والخصوصية', 'معلومات الاستخدام والخصوصية', Icons.description_outlined),
            ])),
            _Row(
              Icons.info_outline_rounded,
              'حول MemoChat',
              'الإصدار والتراخيص',
              () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const MemoLicensesScreen(),
                ),
              ),
            ),
          ]),
          Card(child: ListTile(
            leading: Icon(Icons.logout_rounded, color: Theme.of(context).colorScheme.error),
            title: Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.error)),
            onTap: _confirmSignOut,
          )),
        ],
      ),
    );
  }

}


class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MemoSectionLabel(title),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
        ],
      );
}


class _Row extends StatelessWidget {
  const _Row(this.icon, this.title, this.subtitle, this.onTap, {this.disableTap = false});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool disableTap;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_left_rounded),
        onTap: disableTap ? null : onTap,
      );
}

class _SettingItem {
  const _SettingItem(this.title, this.subtitle, this.icon, {this.switchable = false, this.defaultValue = true});
  final String title;
  final String subtitle;
  final IconData icon;
  final bool switchable;
  final bool defaultValue;
}

class _SettingsSectionScreen extends StatefulWidget {
  const _SettingsSectionScreen({required this.title, required this.icon, required this.items});
  final String title;
  final IconData icon;
  final List<_SettingItem> items;
  @override State<_SettingsSectionScreen> createState() => _SettingsSectionScreenState();
}

class _SettingsSectionScreenState extends State<_SettingsSectionScreen> {
  late final Map<String, bool> _values = {for (final item in widget.items) item.title: item.defaultValue};

  String _key(String title) => 'settings.section.${widget.title}.$title';

  @override
  void initState() {
    super.initState();
    _restore();
  }

  final Map<String, String> _selectedValues = {};

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      for (final item in widget.items) {
        if (item.switchable && prefs.containsKey(_key(item.title))) {
          _values[item.title] = prefs.getBool(_key(item.title)) ?? item.defaultValue;
        }
      }
      if (widget.title == 'الإشعارات والأصوات') {
        _values['إشعارات الرسائل'] = prefs.getBool('notification_message_enabled') ?? true;
        _values['معاينة الرسائل'] = prefs.getBool('notification_message_preview') ?? true;
        _values['صوت الإشعارات'] = prefs.getBool('notification_message_sounds') ?? true;
        _values['الاهتزاز'] = prefs.getBool('notification_message_vibration') ?? true;
        _values['إشعارات المكالمات'] = prefs.getBool('notification_call_enabled') ?? true;
        _values['صوت المكالمات'] = prefs.getBool('notification_call_sounds') ?? true;
        _values['اهتزاز المكالمات'] = prefs.getBool('notification_call_vibration') ?? true;
        _values['الإشعارات الأخرى'] = prefs.getBool('notification_other_enabled') ?? true;
        _values['صوت الإشعارات الأخرى'] = prefs.getBool('notification_other_sounds') ?? true;
        _values['اهتزاز الإشعارات الأخرى'] = prefs.getBool('notification_other_vibration') ?? true;
      }
      for (final item in widget.items) {
        final selected = prefs.getString(_key(item.title));
        if (selected != null) _selectedValues[item.title] = selected;
      }
    });
  }

  Future<void> _setValue(String title, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final notifications = NotificationPreferences(preferences: prefs);
    if (widget.title == 'الإشعارات والأصوات') {
      switch (title) {
        case 'إشعارات الرسائل':
          await notifications.setMessageNotifications(value);
          break;
        case 'معاينة الرسائل':
          await notifications.setMessagePreview(value);
          break;
        case 'صوت الإشعارات':
          await notifications.setMessageSounds(value);
          break;
        case 'الاهتزاز':
          await notifications.setMessageVibration(value);
          break;
        case 'إشعارات المكالمات':
          await notifications.setCallNotifications(value);
          break;
        case 'صوت المكالمات':
          await notifications.setCallSounds(value);
          break;
        case 'اهتزاز المكالمات':
          await notifications.setCallVibration(value);
          break;
        case 'الإشعارات الأخرى':
          await notifications.setOtherNotifications(value);
          break;
        case 'صوت الإشعارات الأخرى':
          await notifications.setOtherSounds(value);
          break;
        case 'اهتزاز الإشعارات الأخرى':
          await notifications.setOtherVibration(value);
          break;
      }
    }
    await prefs.setBool(_key(title), value);
    if (!mounted) return;
    setState(() => _values[title] = value);
  }

  String _displayValue(_SettingItem item) {
    if (item.switchable) return item.subtitle;
    final selected = _selectedValues[item.title];
    return selected == null ? item.subtitle : '$selected • ${item.subtitle}';
  }

  Future<void> _editItem(_SettingItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(item.title);
    final current = prefs.getString(key);
    final options = <String, List<String>>{
      'حجم الخط': ['صغير', 'متوسط', 'كبير', 'كبير جدًا'],
      'خلفية المحادثة': ['افتراضية', 'هادئة', 'فاتحة', 'داكنة'],
      'الإبقاء على المؤرشفة': ['تشغيل', 'إيقاف'],
      'مجلدات المحادثات': ['كل المحادثات', 'المفضلة', 'العمل', 'العائلة'],
      'التنزيل التلقائي للصور': ['دائمًا', 'Wi‑Fi فقط', 'أبدًا'],
      'التنزيل التلقائي للفيديو': ['دائمًا', 'Wi‑Fi فقط', 'أبدًا'],
      'التنزيل التلقائي للملفات': ['دائمًا', 'Wi‑Fi فقط', 'أبدًا'],
      'التخزين': ['عرض معلومات التخزين'],
      'الأجهزة الصوتية': ['تلقائي', 'سماعة الهاتف', 'مكبر الصوت'],
      'خصوصية الحالة': ['جهات اتصالي', 'جهات اتصالي باستثناء...', 'مشاركة مع...'],
      'من يمكنه إضافتي': ['الجميع', 'جهات الاتصال'],
      'مركز المساعدة': ['دليل الاستخدام', 'الخصوصية والأمان'],
      'الإبلاغ عن مشكلة': ['مشكلة في التطبيق', 'مشكلة في الحساب', 'مشكلة في المكالمات'],
      'الشروط والخصوصية': ['الشروط', 'الخصوصية'],
      'إصدار التطبيق': ['عرض الإصدار'],
      'المصادر المفتوحة': ['عرض التراخيص'],
      'التحقق بخطوتين': ['إعداد التحقق بخطوتين لاحقًا'],
      'تنبيهات الأمان': ['تنبيهات الأمان'],
      'الجلسات النشطة': ['عرض الجلسة الحالية'],
    };
    final list = options[item.title];
    if (list == null) return;
    if (item.title == 'التخزين') {
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (_) => AlertDialog(
        title: const Text('التخزين'),
        content: const Text('يمكنك إدارة وسائط MemoChat من إعدادات النظام. لا نحذف ملفاتك أو ندّعي وجود مدير تخزين غير منفذ.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسنًا'))],
      ));
      return;
    }
    if (item.title == 'إصدار التطبيق') {
      if (!mounted) return;
      showAboutDialog(context: context, applicationName: 'MemoChat', applicationLegalese: 'تطبيق مراسلة خاص', children: const [Text('معلومات الإصدار تعتمد على حزمة التطبيق المثبتة.')]);
      return;
    }
    if (item.title == 'المصادر المفتوحة') {
      if (!mounted) return;
      showLicensePage(
        context: context,
        applicationName: 'MemoChat',
        applicationLegalese:
            'إهداء خاص إلى ميمو — في كل لحظة جميلة، تبقى بعض الذكريات أقرب إلى القلب.\n\nإلى ميمو، دائمًا.\n\nمن فلانتشتاين',
      );
      return;
    }
    if (item.title == 'الإبلاغ عن مشكلة') {
      if (!mounted) return;
      final controller = TextEditingController();
      final send = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
        title: const Text('الإبلاغ عن مشكلة'),
        content: TextField(controller: controller, maxLines: 5, decoration: const InputDecoration(hintText: 'اكتب وصف المشكلة')),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إرسال'))],
      ));
      final message = controller.text.trim();
      controller.dispose();
      if (send == true && message.isNotEmpty && Firebase.apps.isNotEmpty) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance.collection('reports').add({
            'reporterId': user.uid,
            'reason': message.substring(0, message.length > 500 ? 500 : message.length),
            'source': 'settings',
            'targetUserId': 'app',
            'createdAt': FieldValue.serverTimestamp(),
          });
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال البلاغ.')));
        }
      }
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900))),
        for (final option in list)
          RadioListTile<String>(value: option, groupValue: current, title: Text(option), onChanged: (v) => Navigator.pop(context, v)),
        const SizedBox(height: 8),
      ])),
    );
    if (selected == null) return;
    await prefs.setString(key, selected);
    if (mounted) setState(() => _selectedValues[item.title] = selected);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w900))),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
          Icon(widget.icon, size: 28),
          const SizedBox(width: 14),
          Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
        ]))),
        const SizedBox(height: 12),
        Card(clipBehavior: Clip.antiAlias, child: Column(children: [
          for (var i = 0; i < widget.items.length; i++)
            Builder(builder: (_) {
              final item = widget.items[i];
              final child = item.switchable
                  ? SwitchListTile(
                      secondary: Icon(item.icon),
                      title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(item.subtitle),
                      value: _values[item.title]!,
                      onChanged: (v) => _setValue(item.title, v),
                    )
                  : ListTile(
                      leading: Icon(item.icon),
                      title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(_displayValue(item)),
                      trailing: const Icon(Icons.chevron_left_rounded),
                      onTap: () => _editItem(item),
                    );
              return Column(children: [child, if (i < widget.items.length - 1) const Divider(height: 1)]);
            }),
        ])),
      ],
    ),
  );
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
                        future: FirebaseFirestore.instance.collection('users').doc(user!.uid).get(),
                        builder: (context, snapshot) {
                          final data = snapshot.data?.data() ?? const <String, dynamic>{};
                          final id = data['publicId']?.toString() ?? data['username']?.toString() ?? 'memo_${user!.uid.substring(0, 8).toLowerCase()}';
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

