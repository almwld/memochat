import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/services/friend_request_service.dart';
import '../../profile/presentation/profile_screen.dart';

class AccountInfoScreen extends StatelessWidget {
  const AccountInfoScreen({
    super.key,
    required this.userId,
    required this.fallbackName,
    this.fallbackPhoto,
  });

  final String userId;
  final String fallbackName;
  final String? fallbackPhoto;

  Future<void> _sendFriendRequest(BuildContext context) async {
    try {
      await FriendRequestService().send(recipientId: userId, recipientName: fallbackName);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال طلب الصداقة.')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إرسال طلب الصداقة: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final name = data['displayName']?.toString().trim().isNotEmpty == true ? data['displayName'].toString().trim() : fallbackName;
        final username = data['username']?.toString().trim() ?? data['publicId']?.toString().trim() ?? '';
        final photo = data['photoUrl']?.toString().trim().isNotEmpty == true ? data['photoUrl'].toString().trim() : fallbackPhoto;
        final bio = data['bio']?.toString().trim() ?? '';
        final cover = data['coverUrl']?.toString().trim() ?? '';
        final isMe = FirebaseAuth.instance.currentUser?.uid == userId;
        return Scaffold(
          appBar: AppBar(title: const Text('معلومات الحساب')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
            children: [
              SizedBox(
                height: 220,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (cover.isNotEmpty) Image.network(cover, fit: BoxFit.cover)
                    else DecoratedBox(decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer)),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Theme.of(context).colorScheme.surface,
                          child: CircleAvatar(
                            radius: 46,
                            backgroundImage: photo?.isNotEmpty == true ? NetworkImage(photo!) : null,
                            child: photo?.isNotEmpty == true ? null : const Icon(Icons.person_rounded, size: 42),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              if (username.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('@$username', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
              ],
              if (bio.isNotEmpty) ...[
                const SizedBox(height: 12),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(bio, textAlign: TextAlign.center)),
              ],
              const SizedBox(height: 18),
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(child: FilledButton.icon(onPressed: () => _sendFriendRequest(context), icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('طلب صداقة'))),
                      const SizedBox(width: 8),
                      Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileScreen(userId: userId))), icon: const Icon(Icons.person_outline_rounded), label: const Text('الملف الكامل'))),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: const [
                    ListTile(leading: Icon(Icons.lock_outline_rounded), title: Text('الخصوصية'), subtitle: Text('معلومات الحساب والمحادثة محمية حسب إعدادات الخصوصية.')),
                    Divider(height: 1),
                    ListTile(leading: Icon(Icons.photo_library_outlined), title: Text('الوسائط المشتركة'), subtitle: Text('ستظهر الوسائط المتبادلة داخل المحادثة.')),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
