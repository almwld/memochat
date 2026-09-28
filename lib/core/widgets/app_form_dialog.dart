import 'package:flutter/material.dart';
Future<T?> showAppFormDialog<T>(BuildContext context, {required String title, required Widget child, String confirmLabel = 'حفظ'}) {
  return showDialog<T>(context: context, builder: (context) => AlertDialog(
    title: Text(title), content: child,
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(confirmLabel))],
  ));
}
