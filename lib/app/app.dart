import 'package:flutter/material.dart';

import '../features/home/presentation/home_screen.dart';

class MemoChatApp extends StatelessWidget {
  const MemoChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MemoChat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A8F83),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F9FA),
      ),
      home: const HomeScreen(),
    );
  }
}
