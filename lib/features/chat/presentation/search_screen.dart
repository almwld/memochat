import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/chat_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/chat_model.dart';
import 'package:memochat/features/chat/presentation/widgets/unified_search_bar.dart';
import 'chat_room_screen.dart';
import 'chat_navigation.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<ChatModel> _results = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onSearchChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _controller.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() { _results = []; _isSearching = false; });
      return;
    }
    setState(() => _isSearching = true);
    final state = context.read<ChatBloc>().state;
    if (state is ChatLoaded) {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final filtered = state.chats.where((chat) {
        final name = chat.getDisplayName(uid).toLowerCase();
        return name.contains(query) ||
            (chat.lastMessage?.toLowerCase().contains(query) ?? false) ||
            (chat.groupName?.toLowerCase().contains(query) ?? false);
      }).toList();
      if (!mounted) return;
      setState(() { _results = filtered; _isSearching = false; });
    } else if (mounted) {
      setState(() => _isSearching = false);
    }
  }

  void _openChat(ChatModel chat) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final otherId = chat.getOtherParticipant(uid);
    if (otherId.isEmpty && !chat.isGroup) return;
    final name = chat.getDisplayName(uid);
    final photo = chat.getDisplayPhoto(uid);
    ChatNavigation.openRoom(context,chatId:chat.id,otherUserId:otherId,otherUserName:name,otherUserImage:photo.isEmpty?null:photo,isGroup:chat.isGroup,groupImage:chat.groupPhoto,lastMessage:chat.lastMessage);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasQuery = _controller.text.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('بحث'),
        actions: [
          if (hasQuery)
            IconButton(
              onPressed: _controller.clear,
              icon: const Icon(Icons.close_rounded),
              tooltip: 'مسح البحث',
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(68),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 12),
            child: UnifiedSearchBar(
              controller: _controller,
              hint: 'ابحث عن محادثة...',
              margin: EdgeInsets.zero,
              backgroundColor: scheme.surfaceContainerHighest,
              borderColor: scheme.outlineVariant,
              textColor: scheme.onSurface,
              hintColor: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator())
          : !hasQuery
              ? _buildInitialState()
              : _results.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 24),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final chat = _results[index];
                        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                        final name = chat.getDisplayName(uid);
                        final photo = chat.getDisplayPhoto(uid);
                        final lastMessage = chat.lastMessage ?? '';
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: scheme.primaryContainer,
                              backgroundImage:
                                  photo.isNotEmpty ? NetworkImage(photo) : null,
                              child: photo.isEmpty
                                  ? Text(
                                      name.isEmpty ? 'م' : name.characters.first,
                                      style: TextStyle(
                                        color: scheme.onPrimaryContainer,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_left_rounded),
                            onTap: () => _openChat(chat),
                          ),
                        );
                      },
                    ),
    );
  }

  Widget _buildInitialState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.search, size: 64, color: Colors.grey[300]),
      const SizedBox(height: 16),
      Text('ابحث عن محادثات', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
      const SizedBox(height: 8),
      Text('ابحث عن الأشخاص أو الرسائل', style: TextStyle(fontSize: 14, color: Colors.grey[400])),
    ]),
  );

  Widget _buildEmptyState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
      const SizedBox(height: 16),
      Text('لا توجد نتائج', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
      const SizedBox(height: 8),
      Text('حاول البحث بكلمات مختلفة', style: TextStyle(fontSize: 14, color: Colors.grey[400])),
    ]),
  );
}
