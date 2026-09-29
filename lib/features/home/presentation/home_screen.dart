import 'package:flutter/material.dart';
import '../../../core/repositories/chat_repository.dart';
import '../../chat/presentation/chat_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.repository, super.key});
  final ChatRepository repository;

  @override
  Widget build(BuildContext context) {
    return const ChatScreen();
  }
}
