import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../bloc/messages/messages_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/services/message_delivery_service.dart';
import 'package:memochat/core/services/chat_reply_context.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/message_bubble.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatId;
  final String? userName;
  final String? userId;
  final bool? isDoctor;
  final String? userImage;
  const ChatDetailScreen({super.key, required this.chatId, this.userName, this.userId, this.isDoctor, this.userImage});
  @override State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}
class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  bool _isLoadingMore = false;
  bool _markingSeen = false;
  bool _keepAtBottom = true;

  @override void initState() {
    super.initState();
    context.read<MessagesBloc>().add(LoadMessages(chatId: widget.chatId, limit: 30));
    _scrollController.addListener(_onScroll);
  }

  @override void dispose() { _scrollController.dispose(); super.dispose(); }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    _keepAtBottom = position.pixels <= 80;
    if (position.maxScrollExtent > 0 && position.pixels >= position.maxScrollExtent * .8) _loadMoreMessages();
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore) return;
    final bloc = context.read<MessagesBloc>();
    final state = bloc.state;
    if (state is! MessagesLoaded || !state.hasMore || state.isLoadingMore) return;
    _isLoadingMore = true;
    _keepAtBottom = false;
    bloc.add(LoadMoreMessages(chatId: widget.chatId, limit: 30));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _isLoadingMore = false);
  }

  void _stickToBottom() {
    if (!_keepAtBottom || !_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients || !_keepAtBottom) return;
      if (_scrollController.position.pixels > 1) _scrollController.animateTo(0, duration: const Duration(milliseconds: 160), curve: Curves.easeOut);
    });
  }

  Future<void> _markConversationSeen() async {
    if (_markingSeen) return;
    _markingSeen = true;
    try { await _chatService.markAsRead(widget.chatId); } catch (e) { debugPrint('Chat mark-as-read failed: $e'); } finally { _markingSeen = false; }
  }

  void _sendText(String text, Timestamp clientTimestamp) {
    final value = text.trim();
    if (value.isEmpty) return;
    _keepAtBottom = true;
    context.read<MessagesBloc>().add(SendMessage(chatId: widget.chatId, text: value));
    _stickToBottom();
  }

  @override Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = widget.userName?.trim().isNotEmpty == true ? widget.userName!.trim() : 'الدردشة';
    final headerColor = isDark ? const Color(0xFF102B2A) : AppColors.primary;
    final inputSurface = isDark ? const Color(0xFF121A29) : Colors.white;
    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          CircleAvatar(radius: 19, backgroundColor: isDark ? const Color(0xFF214442) : Colors.white.withOpacity(.18), backgroundImage: widget.userImage?.trim().isNotEmpty == true ? NetworkImage(widget.userImage!.trim()) : null, child: widget.userImage?.trim().isNotEmpty == true ? null : Icon(Icons.person_rounded, color: Colors.white, size: 22)),
          const SizedBox(width: 10), Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
        backgroundColor: headerColor, foregroundColor: Colors.white, elevation: 3, shadowColor: Colors.black.withOpacity(.18), surfaceTintColor: Colors.transparent,
      ),
      body: Column(children: [
        Expanded(child: BlocConsumer<MessagesBloc, MessagesState>(
          listener: (context, state) {
            if (state is MessagesLoaded) {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                final incomingIds = state.messages.where((m) => m.senderId != uid && !m.isDelivered).map((m) => m.id).toList();
                if (incomingIds.isNotEmpty) unawaited(MessageDeliveryService.instance.acknowledgeDelivered(chatId: widget.chatId, messageIds: incomingIds));
              }
              _stickToBottom();
            }
          },
          builder: (context, state) {
            if (state is MessagesLoading) return const Center(child: CircularProgressIndicator());
            if (state is MessagesError) return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(state.message, textAlign: TextAlign.center)));
            if (state is MessagesLoaded) {
              if (state.messages.isEmpty) return const Center(child: Text('لا توجد رسائل'));
              unawaited(_markConversationSeen());
              final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
              final messages = List.of(state.messages)..sort((a, b) => (b.timestamp ?? Timestamp(0, 0)).compareTo(a.timestamp ?? Timestamp(0, 0)));
              return ListView.builder(
                controller: _scrollController, reverse: true, padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                itemCount: messages.length + (state.isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == messages.length) return const Padding(padding: EdgeInsets.all(8), child: Center(child: CircularProgressIndicator()));
                  final message = messages[index];
                  return MessageBubble(
                    message: message.toFirestore(),
                    isMe: message.senderId == currentUserId,
                    onReply: () {
                      ChatReplyContext.instance.set(widget.chatId, message);
                      if (mounted) setState(() {});
                    },
                  );
                },
              );
            }
            return const SizedBox.shrink();
          },
        )),
        Container(
          decoration: BoxDecoration(color: inputSurface, border: Border(top: BorderSide(color: isDark ? Colors.white.withOpacity(.06) : const Color(0xFFD9E4E3), width: 1)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? .12 : .08), blurRadius: 12, offset: const Offset(0, -3))]),
          child: ChatInputBar(chatId: widget.chatId, onSendMessage: _sendText),
        ),
      ]),
    );
  }
}