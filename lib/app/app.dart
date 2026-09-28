import 'package:flutter/material.dart';
import '../core/repositories/in_memory_chat_repository.dart';
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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A8F83)),
        scaffoldBackgroundColor: const Color(0xFFF7F9FA),
      ),
      home: HomeScreen(repository: repository),
    );
  }
}
