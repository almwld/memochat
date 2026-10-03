import 'package:flutter/material.dart';
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
                      final user = data['userName']?.toString() ?? data['userId']?.toString() ?? 'مستخدم';
                      final mine = data['userId']?.toString() == service.currentUserId;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: (data['userPhoto']?.toString().isNotEmpty ?? false)
                              ? NetworkImage(data['userPhoto'].toString())
                              : null,
                          child: (data['userPhoto']?.toString().isNotEmpty ?? false) ? null : const Icon(Icons.person),
                        ),
                        title: Text(user),
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

