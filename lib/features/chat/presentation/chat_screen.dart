import 'package:flutter/material.dart';
import '../../../core/models/conversation.dart';
import '../../../core/models/message.dart';
import '../../../core/repositories/chat_repository.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({required this.conversation, required this.repository, super.key});
  final Conversation conversation;
  final ChatRepository repository;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await widget.repository.sendMessage(widget.conversation.id, text);
  }

  @override
  Widget build(BuildContext context) {
    final participant = widget.conversation.participant;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          CircleAvatar(child: Text(participant.displayName.characters.first)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(participant.displayName, style: const TextStyle(fontSize: 16)),
            Text(participant.isOnline ? 'متصل الآن' : 'غير متصل', style: const TextStyle(fontSize: 12)),
          ]),
        ]),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.videocam_outlined)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.call_outlined)),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: widget.repository.watchMessages(widget.conversation.id),
            builder: (context, snapshot) {
              final messages = snapshot.data ?? const <ChatMessage>[];
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  return Align(
                    alignment: message.isMine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 310),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: message.isMine ? const Color(0xFF0A8F83) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Flexible(child: Text(message.text, style: TextStyle(color: message.isMine ? Colors.white : const Color(0xFF263238)))),
                        if (message.isMine) ...[
                          const SizedBox(width: 7),
                          Icon(
                            message.status == MessageStatus.read ? Icons.done_all : Icons.done,
                            size: 16,
                            color: message.status == MessageStatus.read ? Colors.lightBlueAccent : Colors.white70,
                          ),
                        ],
                      ]),
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
            child: Row(children: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.add_circle_outline)),
              Expanded(
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'اكتب رسالة...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(onPressed: _send, icon: const Icon(Icons.send_rounded)),
            ]),
          ),
        ),
      ]),
    );
  }
}
