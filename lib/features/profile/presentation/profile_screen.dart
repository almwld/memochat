import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../games/presentation/game_leaderboard_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../services/avatar_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.userId});
  final String? userId;
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _avatarService = AvatarService();
  bool _uploadingAvatar = false;
  bool _uploadingCover = false;
  String get _uid => widget.userId ?? _auth.currentUser?.uid ?? '';
  bool get _isMe => widget.userId == null || widget.userId == _auth.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    if (_uid.isEmpty) return const Scaffold(body: Center(child: Text('الملف الشخصي غير متاح')));
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _db.collection('users').doc(_uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final user = _auth.currentUser;
        final name = data['displayName']?.toString().trim().isNotEmpty == true
            ? data['displayName'].toString().trim()
            : (user?.displayName?.trim().isNotEmpty == true ? user!.displayName! : 'مستخدم MemoChat');
        final publicId = data['publicId']?.toString() ?? data['username']?.toString() ??
            ('memo_' + _uid.substring(0, _uid.length > 8 ? 8 : _uid.length));
        final bio = data['bio']?.toString().trim() ?? '';
        final photo = data['photoUrl']?.toString().trim().isNotEmpty == true
            ? data['photoUrl'].toString() : user?.photoURL;
        final cover = data['coverUrl']?.toString().trim() ?? '';
        final frame = data['profileFrame']?.toString() ?? 'primary';
        final hiddenFromContacts = data['hideFromContacts'] == true;

        return ScrollAwareScaffold(
          appBar: AppBar(
            title: const Text('الملف الشخصي', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            children: [
              _HeroProfile(name: name, publicId: publicId, bio: bio, photoUrl: photo, frame: frame, onEdit: _isMe ? _editProfile : null, onChangePhoto: _isMe ? _changePhoto : null, uploadingPhoto: _uploadingAvatar),
              if (cover.isNotEmpty || _isMe)
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    height: 150,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        cover.isNotEmpty ? Image.network(cover, fit: BoxFit.cover) : DecoratedBox(decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer)),
                        if (_isMe) PositionedDirectional(
                          end: 12, bottom: 12,
                          child: FilledButton.tonalIcon(
                            onPressed: _uploadingCover ? null : _changeCover,
                            icon: _uploadingCover ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.photo_camera_back_outlined),
                            label: const Text('تغيير الغلاف'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              if (_isMe)
                Card(
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        value: hiddenFromContacts,
                        onChanged: (value) => _db.collection('users').doc(_uid).set({'hideFromContacts': value, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)),
                        secondary: const Icon(Icons.visibility_off_outlined),
                        title: const Text('إخفاء الحساب من تواصل', style: TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: const Text('لا يظهر حسابك في قائمة اكتشف وتواصل العامة.'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.auto_awesome_outlined),
                        title: const Text('إطار الملف', style: TextStyle(fontWeight: FontWeight.w800)),
                        trailing: DropdownButton<String>(
                          value: const {'primary','emerald','violet','orange'}.contains(frame) ? frame : 'primary',
                          onChanged: (value) { if (value != null) _db.collection('users').doc(_uid).set({'profileFrame': value, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)); },
                          items: const [DropdownMenuItem(value: 'primary', child: Text('أساسي')), DropdownMenuItem(value: 'emerald', child: Text('زمردي')), DropdownMenuItem(value: 'violet', child: Text('بنفسجي')), DropdownMenuItem(value: 'orange', child: Text('برتقالي'))],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              _StatsStrip(uid: _uid),
              const SizedBox(height: 14),
              _Section(
                title: 'نبذة',
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(bio.isEmpty ? 'لا توجد نبذة مضافة بعد.' : bio, style: const TextStyle(height: 1.6)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'نشاط الألعاب',
                child: Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.emoji_events_outlined)),
                    title: const Text('لوحة الصدارة العالمية', style: TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: const Text('النقاط، الانتصارات وأفضل النتائج'),
                    trailing: const Icon(Icons.chevron_left_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const GameLeaderboardScreen(gameId: 'global', title: 'لوحة الصدارة'),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _Section(
                title: 'الخصوصية والأمان',
                child: Card(
                  child: Column(
                    children: const [
                      ListTile(
                        leading: Icon(Icons.lock_outline_rounded),
                        title: Text('التشفير الطرفي', style: TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('المحادثات الخاصة محمية بالتشفير من الطرف إلى الطرف'),
                      ),
                      Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.verified_user_outlined),
                        title: Text('حساب موثوق', style: TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('هوية الحساب وإعدادات الأمان'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _changePhoto() async {
    if (_uploadingAvatar || _uid.isEmpty) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 86,
    );
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final result = await _avatarService.uploadAndSetOfficialAvatar(
        uid: _uid,
        file: File(picked.path),
      );
      if (!mounted) return;
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث صورة الحساب الرسمية بنجاح')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'تعذر تحديث صورة الحساب')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر رفع صورة الحساب: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _changeCover() async {
    if (_uploadingCover || _uid.isEmpty) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1800, maxHeight: 700, imageQuality: 88);
    if (picked == null) return;
    setState(() => _uploadingCover = true);
    try {
      final result = await _avatarService.uploadAndSetCover(uid: _uid, file: File(picked.path));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.success ? 'تم تحديث غلاف الملف بنجاح' : (result.error ?? 'تعذر تحديث الغلاف'))));
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  Future<void> _editProfile() async {
    final snap = await _db.collection('users').doc(_uid).get();
    final data = snap.data() ?? {};
    final name = TextEditingController(text: data['displayName']?.toString() ?? _auth.currentUser?.displayName ?? '');
    final bio = TextEditingController(text: data['bio']?.toString() ?? '');
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('تعديل الملف', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            TextField(controller: name, textDirection: TextDirection.rtl, maxLength: 60, decoration: const InputDecoration(labelText: 'الاسم')),
            TextField(controller: bio, textDirection: TextDirection.rtl, maxLength: 160, maxLines: 3, decoration: const InputDecoration(labelText: 'النبذة')),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, {'name': name.text.trim(), 'bio': bio.text.trim()}),
                child: const Text('حفظ التغييرات'),
              ),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    bio.dispose();
    if (result == null) return;
    final displayName = result['name']!.isEmpty ? 'مستخدم MemoChat' : result['name']!;
    await _auth.currentUser?.updateDisplayName(displayName);
    await _db.collection('users').doc(_uid).set({
      'displayName': displayName,
      'bio': result['bio'],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

class _HeroProfile extends StatelessWidget {
  const _HeroProfile({
    required this.name,
    required this.publicId,
    required this.bio,
    required this.photoUrl,
    required this.frame,
    this.onEdit,
    this.onChangePhoto,
    this.uploadingPhoto = false,
  });
  final String name;
  final String publicId;
  final String bio;
  final String? photoUrl;
  final String frame;
  final VoidCallback? onEdit;
  final VoidCallback? onChangePhoto;
  final bool uploadingPhoto;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final frameColor = switch (frame) { 'emerald' => const Color(0xFF059669), 'violet' => const Color(0xFF7C3AED), 'orange' => const Color(0xFFEA580C), _ => primary };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: primary, width: 3)),
        ),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: frameColor, width: 4)),
                  child: CircleAvatar(
                  radius: 42,
                  backgroundColor: primary.withOpacity(.12),
                  backgroundImage: photoUrl?.isNotEmpty == true ? NetworkImage(photoUrl!) : null,
                  child: photoUrl?.isNotEmpty == true ? null : Icon(Icons.person_rounded, size: 44, color: primary),
                  ),
                ),
                if (onChangePhoto != null)
                  Material(
                    color: primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: uploadingPhoto ? null : onChangePhoto,
                      child: Padding(
                        padding: const EdgeInsets.all(9),
                        child: uploadingPhoto
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text('@' + publicId, style: TextStyle(color: primary, fontWeight: FontWeight.w800)),
            if (bio.isNotEmpty) ...[
              const SizedBox(height: 9),
              Text(bio, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
            if (onEdit != null) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined), label: const Text('تعديل الملف')),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('gameLeaderboard').doc('global').collection('players').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final d = snapshot.data?.data() ?? {};
        final values = [
          ['النقاط', d['totalScore'] ?? 0, Icons.stars_rounded],
          ['الألعاب', d['gamesPlayed'] ?? 0, Icons.sports_esports_rounded],
          ['الانتصارات', d['wins'] ?? 0, Icons.emoji_events_outlined],
          ['الأفضل', d['bestScore'] ?? 0, Icons.trending_up_rounded],
        ];
        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Row(
              children: values.map((e) => Expanded(
                child: Column(
                  children: [
                    Icon(e[2] as IconData, size: 19, color: AppColors.primary),
                    const SizedBox(height: 4),
                    Text(e[1].toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    Text(e[0].toString(), style: const TextStyle(fontSize: 10)),
                  ],
                ),
              )).toList(),
            ),
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      MemoSectionLabel(title),
      child,
    ],
  );
}
