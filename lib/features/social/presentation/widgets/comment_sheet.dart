import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/social_service.dart';

Future<void> showCommentSheet(BuildContext context, SocialService service, String reelId) async {
  final input = TextEditingController();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * .72,
        child: Column(
          children: [
            const Padding(padding: EdgeInsets.all(16), child: Text('التعليقات', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
            Expanded(
              child: StreamBuilder(
                stream: service.watchComments(reelId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const Center(child: Text('تعذر تحميل التعليقات.'));
                  final docs = snapshot.data?.docs ?? const [];
                  if (docs.isEmpty) return const Center(child: Text('كن أول من يعلّق.'));
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final doc = docs[i];
                      final data = doc.data();
                      final storedName = data['userName']?.toString().trim() ?? '';
                      final userId = data['userId']?.toString().trim() ?? '';
                      final mine = userId == service.currentUserId;
                      return ListTile(
                        // Older comments may only contain userId; resolve the
                        // profile once at render time instead of exposing the UID.
                        title: storedName.isNotEmpty
                            ? Text(storedName)
                            : _CommentAuthorName(userId: userId),
                        leading: CircleAvatar(
                          backgroundImage: (data['userPhoto']?.toString().isNotEmpty ?? false)
                              ? NetworkImage(data['userPhoto'].toString())
                              : null,
                          child: (data['userPhoto']?.toString().isNotEmpty ?? false) ? null : const Icon(Icons.person),
                        ),
                        subtitle: Text(data['text']?.toString() ?? ''),
                        trailing: mine ? IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => service.deleteComment(reelId, doc.id)) : null,
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.viewInsetsOf(sheetContext).bottom + 8),
              child: Row(
                children: [
                  Expanded(child: TextField(controller: input, maxLength: 1000, decoration: const InputDecoration(hintText: 'اكتب تعليقًا...'))),
                  IconButton(
                    onPressed: () async {
                      try {
                        await service.addComment(reelId, input.text);
                        input.clear();
                      } catch (e) {
                        if (sheetContext.mounted) ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(content: Text('تعذر إضافة التعليق: $e')));
                      }
                    },
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  input.dispose();
}
class _CommentAuthorName extends StatelessWidget {
  const _CommentAuthorName({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) return const Text('مستخدم');
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final name = data?['displayName']?.toString().trim() ??
            data?['username']?.toString().trim() ??
            data?['publicId']?.toString().trim() ??
            '';
        return Text(name.isNotEmpty ? name : 'مستخدم');
      },
    );
  }
}
