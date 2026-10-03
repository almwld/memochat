import 'package:flutter/material.dart';
import '../../data/social_service.dart';

Future<void> showReelEditDialog({
  required BuildContext context,
  required SocialService service,
  required String id,
  required Map<String, dynamic> data,
}) async {
  final caption = TextEditingController(text: data['caption']?.toString() ?? '');
  final owner = data['authorId']?.toString() ?? '';
  final isOwner = owner.isNotEmpty;
  try {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('تعديل الوصف'),
              onTap: () async {
                Navigator.pop(sheet);
                await showDialog<void>(
                  context: context,
                  builder: (dialog) => AlertDialog(
                    title: const Text('تعديل الوصف'),
                    content: TextField(controller: caption, maxLines: 5, maxLength: 5000),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('إلغاء')),
                      FilledButton(
                        onPressed: () async {
                          await service.updateReelCaption(id, caption.text);
                          if (dialog.mounted) Navigator.pop(dialog);
                        },
                        child: const Text('حفظ'),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (isOwner) ...[
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined),
                title: Text(data['isPublished'] == false ? 'إظهار الريل' : 'إخفاء الريل'),
                onTap: () async {
                  await service.setReelVisibility(id, data['isPublished'] == false);
                  if (sheet.mounted) Navigator.pop(sheet);
                },
              ),
              ListTile(
                leading: const Icon(Icons.comments_disabled_outlined),
                title: Text(data['commentsEnabled'] == false ? 'تفعيل التعليقات' : 'إيقاف التعليقات'),
                onTap: () async {
                  await service.setCommentsEnabled(id, data['commentsEnabled'] == false);
                  if (sheet.mounted) Navigator.pop(sheet);
                },
              ),
              ListTile(
                leading: Icon(data['isPinned'] == true ? Icons.push_pin_rounded : Icons.push_pin_outlined),
                title: Text(data['isPinned'] == true ? 'إلغاء التثبيت' : 'تثبيت الريل'),
                onTap: () async {
                  await service.pinReel(id, data['isPinned'] != true);
                  if (sheet.mounted) Navigator.pop(sheet);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('حذف الريل'),
                textColor: Colors.red,
                onTap: () async {
                  Navigator.pop(sheet);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dialog) => AlertDialog(
                      title: const Text('حذف الريل؟'),
                      content: const Text('لا يمكن التراجع عن حذف الريل من Firestore.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('إلغاء')),
                        FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('حذف')),
                      ],
                    ),
                  );
                  if (confirm == true) await service.deleteReel(id);
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('إبلاغ'),
              onTap: () {
                Navigator.pop(sheet);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سيتم إضافة نموذج الإبلاغ في المرحلة التالية.')));
              },
            ),
          ],
        ),
      ),
    );
  } finally {
    caption.dispose();
  }
}
