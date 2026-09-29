import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(child: ListTile(
            leading: CircleAvatar(
              backgroundImage: user?.photoURL?.isNotEmpty == true ? NetworkImage(user!.photoURL!) : null,
              child: user?.photoURL?.isNotEmpty == true ? null : const Icon(Icons.person_rounded),
            ),
            title: Text(user?.displayName ?? 'مستخدم MemoChat'),
            subtitle: Text(user?.email ?? 'حساب MemoChat'),
          )),
          const SizedBox(height: 12),
          const _SettingTile(icon: Icons.notifications_outlined, title: 'الإشعارات', subtitle: 'إدارة إشعارات الرسائل والمكالمات'),
          const _SettingTile(icon: Icons.lock_outline_rounded, title: 'الخصوصية', subtitle: 'آخر ظهور، القراءة، وحالة الاتصال'),
          const _SettingTile(icon: Icons.palette_outlined, title: 'المظهر', subtitle: 'فاتح أو داكن حسب إعداد الجهاز'),
          const _SettingTile(icon: Icons.storage_outlined, title: 'البيانات والتخزين', subtitle: 'الوسائط والملفات والاتصال'),
        ],
      ),
    );
  }
}
class _SettingTile extends StatelessWidget {
  const _SettingTile({required this.icon, required this.title, required this.subtitle});
  final IconData icon; final String title; final String subtitle;
  @override Widget build(BuildContext context) => Card(child: ListTile(
    leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_left_rounded),
  ));
}
