import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/models/chat_model.dart';
import '../../core/services/chat_service.dart';

// ============================================================
// Events
// ============================================================

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

class LoadChats extends ChatEvent {}

class RefreshChats extends ChatEvent {}

class DeleteChat extends ChatEvent {
  final String chatId;

  const DeleteChat({required this.chatId});

  @override
  List<Object?> get props => [chatId];
}

class SearchChatsEvent extends ChatEvent {
  final String query;

  const SearchChatsEvent({required this.query});

  @override
  List<Object?> get props => [query];
}

class ArchiveChatEvent extends ChatEvent {
  final String chatId;

  const ArchiveChatEvent({required this.chatId});

  @override
  List<Object?> get props => [chatId];
}

class PinChatEvent extends ChatEvent {
  final String chatId;

  const PinChatEvent({required this.chatId});

  @override
  List<Object?> get props => [chatId];
}

class MuteChatEvent extends ChatEvent {
  final String chatId;

  const MuteChatEvent({required this.chatId});

  @override
  List<Object?> get props => [chatId];
}

// حدث داخلي لتحديث البيانات القادمة من Firestore.
// لا تستخدمه الواجهة مباشرة.
class _ChatsUpdated extends ChatEvent {
  final List<ChatModel> chats;

  const _ChatsUpdated(this.chats);

  @override
  List<Object?> get props => [chats];
}

// ============================================================
// States
// ============================================================

abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ChatLoaded extends ChatState {
  final List<ChatModel> chats;

  const ChatLoaded({required this.chats});

  @override
  List<Object?> get props => [chats];
}

class ChatError extends ChatState {
  final String message;

  const ChatError({required this.message});

  @override
  List<Object?> get props => [message];
}

// ============================================================
// BLoC
// ============================================================

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatService _chatService = ChatService();

  StreamSubscription<List<ChatModel>>? _subscription;

  // القائمة الأصلية القادمة من Firestore.
  List<ChatModel> _allChats = [];

  // آخر نص بحث.
  String _searchQuery = '';

  ChatBloc() : super(ChatInitial()) {
    on<LoadChats>(_onLoadChats);
    on<RefreshChats>(_onRefreshChats);
    on<DeleteChat>(_onDeleteChat);

    on<SearchChatsEvent>(_onSearchChats);
    on<ArchiveChatEvent>(_onArchiveChat);
    on<PinChatEvent>(_onPinChat);
    on<MuteChatEvent>(_onMuteChat);

    on<_ChatsUpdated>(_onChatsUpdated);
    on<_ChatsStreamError>(_onChatsStreamError);
  }

  // ============================================================
  // Load
  // ============================================================

  Future<void> _onLoadChats(
    LoadChats event,
    Emitter<ChatState> emit,
  ) async {
    emit(ChatLoading());

    await _subscription?.cancel();

    try {
      _subscription = _chatService.streamChats().listen(
        (chats) {
          if (!isClosed) {
            add(_ChatsUpdated(chats));
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!isClosed) {
            add(
              _ChatsStreamError(
                error.toString(),
              ),
            );
          }
        },
      );
    } catch (e) {
      emit(ChatError(message: e.toString()));
    }
  }

  // ============================================================
  // Firestore stream update
  // ============================================================

  void _onChatsUpdated(
    _ChatsUpdated event,
    Emitter<ChatState> emit,
  ) {
    _allChats = List<ChatModel>.unmodifiable(event.chats);

    emit(
      ChatLoaded(
        chats: _applySearch(_allChats),
      ),
    );
  }

  // ============================================================
  // Stream error
  // ============================================================

  void _onChatsStreamError(
    _ChatsStreamError event,
    Emitter<ChatState> emit,
  ) {
    emit(ChatError(message: event.message));
  }

  // ============================================================
  // Search
  // ============================================================

  void _onSearchChats(
    SearchChatsEvent event,
    Emitter<ChatState> emit,
  ) {
    _searchQuery = event.query.trim().toLowerCase();

    if (state is ChatLoaded) {
      emit(
        ChatLoaded(
          chats: _applySearch(_allChats),
        ),
      );
    } else if (_allChats.isNotEmpty) {
      emit(
        ChatLoaded(
          chats: _applySearch(_allChats),
        ),
      );
    }
  }

  List<ChatModel> _applySearch(List<ChatModel> chats) {
    if (_searchQuery.isEmpty) {
      return List<ChatModel>.unmodifiable(chats);
    }

    return List<ChatModel>.unmodifiable(
      chats.where((chat) {
        final name = _getSearchableText(chat.getDisplayName(
          _chatService.currentUserId ?? '',
        ));

        final lastMessage =
            _getSearchableText(chat.lastMessage ?? '');

        final groupName =
            _getSearchableText(chat.groupName ?? '');

        return name.contains(_searchQuery) ||
            lastMessage.contains(_searchQuery) ||
            groupName.contains(_searchQuery);
      }),
    );
  }

  String _getSearchableText(String value) {
    return value.trim().toLowerCase();
  }

  // ============================================================
  // Refresh
  // ============================================================

  Future<void> _onRefreshChats(
    RefreshChats event,
    Emitter<ChatState> emit,
  ) async {
    add(LoadChats());
  }

  // ============================================================
  // Delete
  // ============================================================

  Future<void> _onDeleteChat(
    DeleteChat event,
    Emitter<ChatState> emit,
  ) async {
    try {
      await _chatService.deleteChat(event.chatId);
    } catch (e) {
      emit(ChatError(message: e.toString()));
    }
  }

  // ============================================================
  // Archive
  // ============================================================

  Future<void> _onArchiveChat(
    ArchiveChatEvent event,
    Emitter<ChatState> emit,
  ) async {
    try {
      final chat = _findChat(event.chatId);

      if (chat == null) {
        emit(const ChatError(message: 'المحادثة غير موجودة'));
        return;
      }

      await _chatService.archiveChat(
        event.chatId,
        !chat.isArchived,
      );
    } catch (e) {
      emit(ChatError(message: e.toString()));
    }
  }

  // ============================================================
  // Pin
  // ============================================================

  Future<void> _onPinChat(
    PinChatEvent event,
    Emitter<ChatState> emit,
  ) async {
    try {
      final chat = _findChat(event.chatId);

      if (chat == null) {
        emit(const ChatError(message: 'المحادثة غير موجودة'));
        return;
      }

      await _chatService.pinChat(
        event.chatId,
        !chat.isPinned,
      );
    } catch (e) {
      emit(ChatError(message: e.toString()));
    }
  }

  // ============================================================
  // Mute
  // ============================================================

  Future<void> _onMuteChat(
    MuteChatEvent event,
    Emitter<ChatState> emit,
  ) async {
    try {
      final chat = _findChat(event.chatId);

      if (chat == null) {
        emit(const ChatError(message: 'المحادثة غير موجودة'));
        return;
      }

      await _chatService.muteChat(
        event.chatId,
        !chat.isMuted,
      );
    } catch (e) {
      emit(ChatError(message: e.toString()));
    }
  }

  ChatModel? _findChat(String chatId) {
    for (final chat in _allChats) {
      if (chat.id == chatId) {
        return chat;
      }
    }

    return null;
  }

  // ============================================================
  // Close
  // ============================================================

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;

    return super.close();
  }
}

// ============================================================
// Internal stream error event
// ============================================================

class _ChatsStreamError extends ChatEvent {
  final String message;

  const _ChatsStreamError(this.message);

  @override
  List<Object?> get props => [message];
}
