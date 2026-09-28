import 'package:flutter/material.dart';
import '../core/repositories/in_memory_chat_repository.dart';
import '../core/theme/app_theme.dart';
import '../features/home/presentation/home_screen.dart';

class MemoChatApp extends StatefulWidget {
  const MemoChatApp({super.key});
  @override
  State<MemoChatApp> createState() => _MemoChatAppState();
}

class _MemoChatAppState extends State<MemoChatApp> {
  late final repository = InMemoryChatRepository();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MemoChat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: HomeScreen(repository: repository),
    );
  }
}
