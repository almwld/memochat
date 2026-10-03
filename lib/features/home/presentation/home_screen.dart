import 'package:flutter/material.dart';
import '../../../core/repositories/chat_repository.dart';
import 'main_shell.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.repository,
    required this.onThemeModeChanged,
    required this.onSignOut,
    this.firebaseFailed = false,
    super.key,
  });

  final ChatRepository repository;
  final bool firebaseFailed;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => MainShell(
        repository: repository,
        onThemeModeChanged: onThemeModeChanged,
        onSignOut: onSignOut,
      );
}
