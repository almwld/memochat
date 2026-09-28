import 'package:flutter/material.dart';
Future<bool> showConfirmDeleteDialog(BuildContext context, {String title = 'تأكيد الحذف', String message = 'هل تريد حذف هذا العنصر؟'}) async {
  final result = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
    title: Text(title), content: Text(message),
    actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف'))],
  ));
  return result ?? false;
}
