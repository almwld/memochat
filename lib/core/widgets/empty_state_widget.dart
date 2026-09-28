import 'package:flutter/material.dart';
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({super.key, required this.title, this.subtitle, this.icon = Icons.inbox_outlined});
  final String title; final String? subtitle; final IconData icon;
  @override Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 48), const SizedBox(height: 12), Text(title, style: Theme.of(context).textTheme.titleMedium), if (subtitle != null) ...[const SizedBox(height: 6), Text(subtitle!)]]));
}
