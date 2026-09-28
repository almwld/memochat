import 'package:flutter/material.dart';
import '../theme/app_dimensions.dart';
class AppButton extends StatelessWidget {
  const AppButton({super.key, required this.label, required this.onPressed, this.icon});
  final String label; final VoidCallback? onPressed; final Widget? icon;
  @override Widget build(BuildContext context) => SizedBox(width: double.infinity, height: AppDimensions.buttonHeight, child: FilledButton.icon(onPressed: onPressed, icon: icon ?? const SizedBox.shrink(), label: Text(label)));
}
