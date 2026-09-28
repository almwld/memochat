import 'package:flutter/material.dart';
import 'app_button.dart';
class LoadingButton extends StatelessWidget {
  const LoadingButton({super.key, required this.label, required this.loading, required this.onPressed});
  final String label; final bool loading; final VoidCallback? onPressed;
  @override Widget build(BuildContext context) => AppButton(label: label, onPressed: loading ? null : onPressed, icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : null);
}
