import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/models/message_model.dart';
import '../../core/services/chat_service.dart';

// ============================================================
// الأحداث
// ============================================================

abstract class MessagesEvent extends Equatable {
  const MessagesEvent();

  @override
  List<Object?> get props => [];
}

class LoadMessages extends MessagesEvent {
  final String chatId;
  final int limit;

  const LoadMessages({
    required this.chatId,
    this.limit = 30,
  });

  @override
  List<Object?> get props => [chatId, limit];
}

class LoadMoreMessages extends MessagesEvent {
  final String chatId;
  final int limit;

  const LoadMoreMessages({
    required this.chatId,
    this.limit = 30,
  });

  @override
  List<Object?> get props => [chatId, limit];
}

class SendMessage extends MessagesEvent {
  final String chatId;
  final String text;
  final String? imageUrl;
  final String? audioUrl;
  final String? fileUrl;
  final String? locationUrl;
  final String? replyToId;
  final String? idempotencyKey;

  const SendMessage({
    required this.chatId,
    required this.text,
    this.imageUrl,
    this.audioUrl,
    this.fileUrl,
    this.locationUrl,
    this.replyToId,
    this.idempotencyKey,
  });

  @override
  List<Object?> get props => [
        chatId,
        text,
        imageUrl,
        audioUrl,
        fileUrl,
        locationUrl,
        replyToId,
        idempotencyKey,
      ];
}

class DeleteMessage extends MessagesEvent {
  final String chatId;
  final String messageId;

  const DeleteMessage({
    required this.chatId,
    required this.messageId,
  });

  @override
  List<Object?> get props => [
        chatId,
        messageId,
      ];
}

class AddReaction extends MessagesEvent {
  final String chatId;
  final String messageId;
  final String emoji;

  const AddReaction({
    required this.chatId,
    required this.messageId,
    required this.emoji,
  });

  @override
  List<Object?> get props => [
        chatId,
        messageId,
        emoji,
      ];
}

class MarkMessagesRead extends MessagesEvent {
  final String chatId;

  const MarkMessagesRead({
    required this.chatId,
  });

  @override
  List<Object?> get props => [chatId];
}

// ============================================================
// الحالات
// ============================================================

abstract class MessagesState extends Equatable {
  const MessagesState();

  @override
  List<Object?> get props => [];
}

class MessagesInitial extends MessagesState {}

class MessagesLoading extends MessagesState {}

class MessagesLoaded extends MessagesState {
  final List<MessageModel> messages;
  final bool hasMore;
  final bool isLoadingMore;
  final DocumentSnapshot? lastDocument;

  const MessagesLoaded({
    required this.messages,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.lastDocument,
  });

  @override
  List<Object?> get props => [
        messages,
        hasMore,
        isLoadingMore,
        lastDocument,
      ];
}

class MessagesError extends MessagesState {
  final String message;

  const MessagesError({
    required this.message,
  });

  @override
  List<Object?> get props => [message];
}

class MessageSending extends MessagesState {}

// ============================================================
// أحداث داخلية
// ============================================================

class _MessagesUpdated extends MessagesEvent {
  final String chatId;
  final MessagePaginationResult result;
  final int limit;

  const _MessagesUpdated({
    required this.chatId,
    required this.result,
    required this.limit,
  });

  @override
  List<Object?> get props => [
        chatId,
        result.messages,
        result.lastDocument,
        result.hasMore,
        limit,
      ];
}

class _MessagesStreamError extends MessagesEvent {
  final String chatId;
  final String message;

  const _MessagesStreamError({
    required this.chatId,
    required this.message,
  });

  @override
  List<Object?> get props => [
        chatId,
        message,
      ];
}

// ============================================================
// MessagesBloc
// ============================================================

class MessagesBloc
    extends Bloc<MessagesEvent, MessagesState> {
  final ChatService _chatService =
      ChatService();

  StreamSubscription<MessagePaginationResult>?
      _subscription;

  DocumentSnapshot? _lastDocument;

  bool _hasMore = true;

  bool _isPaginating = false;

  bool _hasReceivedInitialSnapshot = false;

  bool _hasPaginated = false;

  String? _currentChatId;

  List<MessageModel> _loadedMessages = [];

  MessagesBloc()
      : super(MessagesInitial()) {
    on<LoadMessages>(
      _onLoadMessages,
    );

    on<LoadMoreMessages>(
      _onLoadMoreMessages,
    );

    on<SendMessage>(
      _onSendMessage,
    );

    on<DeleteMessage>(
      _onDeleteMessage,
    );

    on<AddReaction>(
      _onAddReaction,
    );

    on<MarkMessagesRead>(
      _onMarkMessagesRead,
    );

    on<_MessagesUpdated>(
      _onMessagesUpdated,
    );

    on<_MessagesStreamError>(
      _onMessagesStreamError,
    );
  }

  // ============================================================
  // تحميل الرسائل لأول مرة
  // ============================================================

  Future<void> _onLoadMessages(
    LoadMessages event,
    Emitter<MessagesState> emit,
  ) async {
    emit(MessagesLoading());

    _currentChatId = event.chatId;

    _lastDocument = null;
    _hasMore = true;

    _isPaginating = false;
    _hasReceivedInitialSnapshot = false;
    _hasPaginated = false;

    _loadedMessages = [];

    await _subscription?.cancel();
    _subscription = null;

    try {
      _subscription = _chatService
          .streamMessages(
            event.chatId,
            limit: event.limit,
          )
          .listen(
        (result) {
          if (isClosed) {
            return;
          }

          add(
            _MessagesUpdated(
              chatId: event.chatId,
              result: result,
              limit: event.limit,
            ),
          );
        },
        onError: (
          Object error,
          StackTrace stackTrace,
        ) {
          if (isClosed) {
            return;
          }

          add(
            _MessagesStreamError(
              chatId: event.chatId,
              message: error.toString(),
            ),
          );
        },
      );

      add(
        MarkMessagesRead(
          chatId: event.chatId,
        ),
      );
    } catch (e) {
      emit(
        MessagesError(
          message: e.toString(),
        ),
      );
    }
  }

  // ============================================================
  // دمج الرسائل
  // ============================================================

  List<MessageModel> _mergeMessages(
    List<MessageModel> existing,
    List<MessageModel> incoming,
  ) {
    final byId =
        <String, MessageModel>{};

    for (final message in existing) {
      byId[message.id] = message;
    }

    for (final message in incoming) {
      // الرسالة القادمة من Firestore
      // أحدث من النسخة المحلية.
      byId[message.id] = message;
    }

    final merged =
        byId.values.toList();

    merged.sort(
      (a, b) {
        final at = a.timestamp;
        final bt = b.timestamp;

        if (at == null && bt == null) {
          return 0;
        }

        if (at == null) {
          return 1;
        }

        if (bt == null) {
          return -1;
        }

        return bt.compareTo(at);
      },
    );

    return merged;
  }

  // ============================================================
  // تحديث Stream
  // ============================================================

  void _onMessagesUpdated(
    _MessagesUpdated event,
    Emitter<MessagesState> emit,
  ) {
    if (event.chatId != _currentChatId) {
      return;
    }

    final result = event.result;

    if (!_hasReceivedInitialSnapshot) {
      _hasReceivedInitialSnapshot = true;

      _loadedMessages =
          List<MessageModel>.from(
        result.messages,
      );

      _lastDocument =
          result.lastDocument;

      _hasMore =
          result.hasMore;
    } else {
      _loadedMessages =
          _mergeMessages(
        _loadedMessages,
        result.messages,
      );

      // قبل تنفيذ pagination،
      // يمكن تحديث cursor من الـ stream.
      //
      // بعد pagination لا نعيد cursor للخلف،
      // لأن stream يعرض الصفحة الأولى فقط.
      if (!_hasPaginated) {
        _lastDocument =
            result.lastDocument;

        _hasMore =
            result.hasMore;
      }
    }

    emit(
      MessagesLoaded(
        messages:
            List<MessageModel>.unmodifiable(
          _loadedMessages,
        ),
        hasMore: _hasMore,
        isLoadingMore:
            _isPaginating,
        lastDocument:
            _lastDocument,
      ),
    );
  }

  // ============================================================
  // خطأ Stream
  // ============================================================

  void _onMessagesStreamError(
    _MessagesStreamError event,
    Emitter<MessagesState> emit,
  ) {
    if (event.chatId != _currentChatId) {
      return;
    }

    emit(
      MessagesError(
        message: event.message,
      ),
    );
  }

  // ============================================================
  // تحميل رسائل أقدم
  // ============================================================

  Future<void> _onLoadMoreMessages(
    LoadMoreMessages event,
    Emitter<MessagesState> emit,
  ) async {
    if (state is! MessagesLoaded) {
      return;
    }

    final currentState =
        state as MessagesLoaded;

    if (_isPaginating) {
      return;
    }

    if (currentState.isLoadingMore) {
      return;
    }

    if (!_hasMore ||
        !currentState.hasMore) {
      return;
    }

    if (_currentChatId !=
        event.chatId) {
      return;
    }

    // لا يوجد cursor.
    if (_lastDocument == null) {
      return;
    }

    _isPaginating = true;

    emit(
      MessagesLoaded(
        messages:
            currentState.messages,
        hasMore:
            currentState.hasMore,
        isLoadingMore: true,
        lastDocument:
            _lastDocument,
      ),
    );

    try {
      final result =
          await _chatService
              .getMoreMessages(
        chatId: event.chatId,
        limit: event.limit,
        startAfter:
            _lastDocument,
      );

      if (result.messages.isEmpty) {
        _hasMore = false;
        _isPaginating = false;

        emit(
          MessagesLoaded(
            messages:
                List<MessageModel>.unmodifiable(
              _loadedMessages,
            ),
            hasMore: false,
            isLoadingMore: false,
            lastDocument:
                _lastDocument,
          ),
        );

        return;
      }

      _loadedMessages =
          _mergeMessages(
        _loadedMessages,
        result.messages,
      );

      _lastDocument =
          result.lastDocument;

      _hasMore =
          result.hasMore;

      _hasPaginated = true;

      _isPaginating = false;

      emit(
        MessagesLoaded(
          messages:
              List<MessageModel>.unmodifiable(
            _loadedMessages,
          ),
          hasMore: _hasMore,
          isLoadingMore: false,
          lastDocument:
              _lastDocument,
        ),
      );
    } catch (e) {
      _isPaginating = false;

      emit(
        MessagesLoaded(
          messages:
              List<MessageModel>.unmodifiable(
            _loadedMessages,
          ),
          hasMore: _hasMore,
          isLoadingMore: false,
          lastDocument:
              _lastDocument,
        ),
      );
    }
  }

  // ============================================================
  // إرسال رسالة
  // ============================================================

  Future<void> _onSendMessage(
    SendMessage event,
    Emitter<MessagesState> emit,
  ) async {
    try {
      final idempotencyKey =
          event.idempotencyKey ??
              '${event.chatId}_${DateTime.now().millisecondsSinceEpoch}_${event.text.hashCode}';

      await _chatService.sendMessage(
        chatId: event.chatId,
        text: event.text,
        imageUrl: event.imageUrl,
        audioUrl: event.audioUrl,
        fileUrl: event.fileUrl,
        locationUrl:
            event.locationUrl,
        replyToId:
            event.replyToId,
        idempotencyKey:
            idempotencyKey,
      );

      // لا نرسل MessageSending هنا
      // حتى لا تختفي واجهة المحادثة.
      //
      // الـ Firestore Stream سيحدث
      // تلقائيًا بعد نجاح الإرسال.
    } catch (e) {
      emit(
        MessagesError(
          message: e.toString(),
        ),
      );
    }
  }

  // ============================================================
  // حذف رسالة
  // ============================================================

  Future<void> _onDeleteMessage(
    DeleteMessage event,
    Emitter<MessagesState> emit,
  ) async {
    try {
      await _chatService.deleteMessage(
        event.chatId,
        event.messageId,
      );

      // الـ Stream سيحدث تلقائيًا.
    } catch (e) {
      emit(
        MessagesError(
          message: e.toString(),
        ),
      );
    }
  }

  // ============================================================
  // إضافة Reaction
  // ============================================================

  Future<void> _onAddReaction(
    AddReaction event,
    Emitter<MessagesState> emit,
  ) async {
    try {
      await _chatService.addReaction(
        event.chatId,
        event.messageId,
        event.emoji,
      );

      // الـ Stream سيحدث تلقائيًا.
    } catch (e) {
      emit(
        MessagesError(
          message: e.toString(),
        ),
      );
    }
  }

  // ============================================================
  // تعليم الرسائل كمقروءة
  // ============================================================

  Future<void> _onMarkMessagesRead(
    MarkMessagesRead event,
    Emitter<MessagesState> emit,
  ) async {
    try {
      await _chatService.markAsRead(
        event.chatId,
      );
    } catch (e) {
      print(
        '⚠️ Error marking messages as read: $e',
      );
    }
  }

  // ============================================================
  // إغلاق BLoC
  // ============================================================

  @override
  Future<void> close() async {
    await _subscription?.cancel();

    _subscription = null;

    return super.close();
  }
}
