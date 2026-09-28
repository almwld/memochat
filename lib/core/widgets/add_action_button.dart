import 'package:flutter/material.dart';
class AddActionButton extends StatelessWidget {
  const AddActionButton({super.key, required this.onPressed, this.tooltip = 'إضافة'});
  final VoidCallback onPressed; final String tooltip;
  @override Widget build(BuildContext context) => FloatingActionButton(onPressed: onPressed, tooltip: tooltip, child: const Icon(Icons.add));
}
