// ============================================================
// ⚙️ ChatSettingsScreen - شاشة إعدادات الدردشة
// ============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/toast_service.dart';
import '../../../core/services/chat_preferences_service.dart';
import '../../../core/notifications/notification_preferences.dart';

class ChatSettingsScreen extends StatefulWidget {
  const ChatSettingsScreen({super.key, this.chatId});
  final String? chatId;
  @override State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  bool _darkMode = false, _notifications = true, _sound = true, _vibration = true;
  double _fontSize = 14.0;
  bool _saving = false;
  String _wallpaper = 'default';
  final _chatPrefs = ChatPreferencesService();

  @override void initState() { super.initState(); _loadSettings(); }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationPreferences = NotificationPreferences(preferences: prefs);
    if (!mounted) return;
    var fontSize = prefs.getDouble('font_size') ?? 14.0;
    var wallpaper = 'default';
    if (widget.chatId != null && widget.chatId!.isNotEmpty) {
      fontSize = await _chatPrefs.getFontSize(widget.chatId!) ?? fontSize;
      wallpaper = await _chatPrefs.getWallpaper(widget.chatId!) ?? 'default';
    }
    if (!mounted) return;
    setState(() {
      _darkMode = prefs.getBool('dark_mode') ?? false;
      _notifications = prefs.getBool('notification_message_enabled') ?? true;
      _sound = prefs.getBool('notification_message_sounds') ?? true;
      _vibration = prefs.getBool('notification_message_vibration') ?? true;
      _fontSize = fontSize;
      _wallpaper = wallpaper;
    });
  }

  Future<void> _saveSettings() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _darkMode);
    final notificationPreferences = NotificationPreferences(preferences: prefs);
    await notificationPreferences.setMessageNotifications(_notifications);
    await notificationPreferences.setMessageSounds(_sound);
    await notificationPreferences.setMessageVibration(_vibration);
    await prefs.setDouble('font_size', _fontSize);
    if (widget.chatId != null && widget.chatId!.isNotEmpty) {
      await _chatPrefs.setFontSize(widget.chatId!, _fontSize);
      await _chatPrefs.setWallpaper(widget.chatId!, _wallpaper);
    }
    if (mounted) ToastService.showSuccess('تم حفظ الإعدادات');
    } catch (_) { if (mounted) ToastService.showError('تعذر حفظ إعدادات الدردشة'); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('إعدادات الدردشة'),
        actions: [
          IconButton(
            tooltip: 'حفظ',
            icon: _saving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            onPressed: _saving ? null : _saveSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.only(bottom: 24),
        children: [
          _buildSection(
            title: 'المظهر',
            children: [
              SwitchListTile(
                title: const Text('الوضع المظلم'),
                subtitle: const Text('تفعيل الوضع المظلم في الدردشة'),
                value: _darkMode,
                onChanged: (v) => setState(() => _darkMode = v),
                activeColor: scheme.primary,
              ),
              ListTile(
                leading: Icon(Icons.text_fields, color: scheme.primary),
                title: const Text('حجم الخط'),
                subtitle: Text('${_fontSize.toStringAsFixed(0)} بكسل'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'تصغير',
                      icon: const Icon(Icons.remove_rounded, size: 20),
                      onPressed: () {
                        if (_fontSize > 10) setState(() => _fontSize--);
                      },
                    ),
                    IconButton(
                      tooltip: 'تكبير',
                      icon: const Icon(Icons.add_rounded, size: 20),
                      onPressed: () {
                        if (_fontSize < 24) setState(() => _fontSize++);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.chatId != null && widget.chatId!.isNotEmpty)
            _buildSection(
              title: 'تخصيص هذه المحادثة',
              children: [
                ListTile(
                  leading: Icon(Icons.wallpaper_outlined, color: scheme.primary),
                  title: const Text('خلفية المحادثة'),
                  subtitle: Text(_wallpaperLabel(_wallpaper)),
                  onTap: _chooseWallpaper,
                ),
                ListTile(
                  leading: Icon(Icons.text_fields, color: scheme.primary),
                  title: const Text('حجم الخط لهذه المحادثة'),
                  subtitle: Text('${_fontSize.toStringAsFixed(0)} بكسل'),
                  trailing: SizedBox(
                    width: 150,
                    child: Slider(
                      min: 10,
                      max: 24,
                      divisions: 14,
                      value: _fontSize,
                      onChanged: (v) => setState(() => _fontSize = v),
                    ),
                  ),
                ),
              ],
            ),
          _buildSection(
            title: 'الإشعارات',
            children: [
              SwitchListTile(
                title: const Text('الإشعارات'),
                subtitle: const Text('تفعيل إشعارات الدردشة'),
                value: _notifications,
                onChanged: (v) => setState(() => _notifications = v),
                activeColor: scheme.primary,
              ),
              SwitchListTile(
                title: const Text('الصوت'),
                subtitle: const Text('تشغيل صوت الإشعارات'),
                value: _sound,
                onChanged: (v) => setState(() => _sound = v),
                activeColor: scheme.primary,
              ),
              SwitchListTile(
                title: const Text('الاهتزاز'),
                subtitle: const Text('تفعيل الاهتزاز مع الإشعارات'),
                value: _vibration,
                onChanged: (v) => setState(() => _vibration = v),
                activeColor: scheme.primary,
              ),
            ],
          ),
          _buildSection(
            title: 'البيانات',
            children: [
              ListTile(
                leading: Icon(Icons.delete_forever_outlined, color: scheme.error),
                title: Text('حذف جميع المحادثات', style: TextStyle(color: scheme.error)),
                subtitle: Text('حذف جميع المحادثات نهائياً', style: TextStyle(color: scheme.error)),
                onTap: _showDeleteConfirmation,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 18, 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsetsDirectional.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  String _wallpaperLabel(String value) => switch (value) {
    'mint' => 'نعناعي',
    'paper' => 'ورقي',
    'dark' => 'داكن',
    _ => 'الافتراضية',
  };

  Future<void> _chooseWallpaper() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final item in const [('default', 'الافتراضية'), ('mint', 'نعناعي'), ('paper', 'ورقي'), ('dark', 'داكن')])
          ListTile(
            leading: const Icon(Icons.wallpaper_outlined),
            title: Text(item.$2),
            trailing: _wallpaper == item.$1 ? const Icon(Icons.check, color: AppColors.primary) : null,
            onTap: () => Navigator.pop(context, item.$1),
          ),
        const SizedBox(height: 8),
      ])),
    );
    if (value != null) setState(() => _wallpaper = value);
  }

  void _showDeleteConfirmation() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف جميع المحادثات'),
        content: const Text('الحذف الجماعي غير متاح حاليًا. لم يتم حذف أي محادثة.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('حسنًا'),
          ),
        ],
      ),
    );
  }
}
