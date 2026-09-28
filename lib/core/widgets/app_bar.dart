import 'package:flutter/material.dart';
class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppAppBar({super.key, required this.title, this.actions, this.leading});
  final String title; final List<Widget>? actions; final Widget? leading;
  @override Widget build(BuildContext context) => AppBar(title: Text(title), leading: leading, actions: actions);
  @override Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
