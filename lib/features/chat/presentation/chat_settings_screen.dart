// ============================================================
// ⚙️ ChatSettingsScreen - شاشة إعدادات الدردشة
// ============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/toast_service.dart';
import '../../../core/services/chat_preferences_service.dart';

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
      _notifications = prefs.getBool('notifications') ?? true;
      _sound = prefs.getBool('sound') ?? true;
      _vibration = prefs.getBool('vibration') ?? true;
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
    await prefs.setBool('notifications', _notifications);
    await prefs.setBool('sound', _sound);
    await prefs.setBool('vibration', _vibration);
    await prefs.setDouble('font_size', _fontSize);
    if (widget.chatId != null && widget.chatId!.isNotEmpty) {
      await _chatPrefs.setFontSize(widget.chatId!, _fontSize);
      await _chatPrefs.setWallpaper(widget.chatId!, _wallpaper);
    }
    if (mounted) ToastService.showSuccess('تم حفظ الإعدادات');
    } catch (_) { if (mounted) ToastService.showError('تعذر حفظ إعدادات الدردشة'); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.grey[50],
    appBar: AppBar(title: const Text('إعدادات الدردشة'), backgroundColor: AppColors.primary, foregroundColor: Colors.white, actions: [IconButton(icon: _saving ? const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)) : const Icon(Icons.save), onPressed: _saving ? null : _saveSettings)]),
    body: ListView(children: [
      _buildSection(title: 'المظهر', children: [
        SwitchListTile(title: const Text('الوضع المظلم'), subtitle: const Text('تفعيل الوضع المظلم في الدردشة'), value: _darkMode, onChanged: (v) => setState(() => _darkMode = v), activeColor: AppColors.primary),
        ListTile(leading: const Icon(Icons.text_fields, color: AppColors.primary), title: const Text('حجم الخط'), subtitle: Text('${_fontSize.toStringAsFixed(0)} بكسل'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.remove, size: 20), onPressed: () { if (_fontSize > 10) setState(() => _fontSize--); }), IconButton(icon: const Icon(Icons.add, size: 20), onPressed: () { if (_fontSize < 24) setState(() => _fontSize++); })])),
      ]),
      if (widget.chatId != null && widget.chatId!.isNotEmpty)
        _buildSection(title: 'تخصيص هذه المحادثة', children: [
          ListTile(leading: const Icon(Icons.wallpaper_outlined, color: AppColors.primary), title: const Text('خلفية المحادثة'), subtitle: Text(_wallpaperLabel(_wallpaper)), onTap: _chooseWallpaper),
          ListTile(
            leading: const Icon(Icons.text_fields, color: AppColors.primary),
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
        ]),
      _buildSection(title: 'الإشعارات', children: [
        SwitchListTile(title: const Text('الإشعارات'), subtitle: const Text('تفعيل إشعارات الدردشة'), value: _notifications, onChanged: (v) => setState(() => _notifications = v), activeColor: AppColors.primary),
        SwitchListTile(title: const Text('الصوت'), subtitle: const Text('تشغيل صوت الإشعارات'), value: _sound, onChanged: (v) => setState(() => _sound = v), activeColor: AppColors.primary),
        SwitchListTile(title: const Text('الاهتزاز'), subtitle: const Text('تفعيل الاهتزاز مع الإشعارات'), value: _vibration, onChanged: (v) => setState(() => _vibration = v), activeColor: AppColors.primary),
      ]),
      _buildSection(title: 'البيانات', children: [ListTile(leading: const Icon(Icons.delete_forever, color: Colors.red), title: const Text('حذف جميع المحادثات', style: TextStyle(color: Colors.red)), subtitle: const Text('حذف جميع المحادثات نهائياً', style: TextStyle(color: Colors.red)), onTap: _showDeleteConfirmation)]),
    ]),
  );

  Widget _buildSection({required String title, required List<Widget> children}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600]))), Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Column(children: children))]);

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
    showDialog(context: context, builder: (dialogContext) => AlertDialog(title: const Text('حذف جميع المحادثات'), content: const Text('هل أنت متأكد من حذف جميع المحادثات؟ هذا الإجراء لا يمكن التراجع عنه.'), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')), TextButton(onPressed: () { Navigator.pop(dialogContext); ToastService.showSuccess('تم حذف جميع المحادثات'); }, style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('حذف الكل'))]));
  }
}
