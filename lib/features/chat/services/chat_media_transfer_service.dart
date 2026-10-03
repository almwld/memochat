import 'dart:async';
import 'dart:io';

import '../../../core/media/media_transfer_engine.dart';

const String chatMediaTransferTask = mediaTransferTask;

@pragma('vm:entry-point')
void chatMediaTransferCallbackDispatcher() {
  mediaTransferCallbackDispatcher();
}

class ChatMediaTransferService {
  ChatMediaTransferService._();
  static final instance = ChatMediaTransferService._();

  final _engine = MediaTransferEngine.instance;

  Future<void> initialize({bool startBackgroundWorker = true}) =>
      _engine.initialize(startWorker: startBackgroundWorker);

  Future<String> enqueue({
    required String chatId,
    required File sourceFile,
    required String type,
    required String folder,
    required String preview,
    String? fileName,
    String? fileSize,
    String? mimeType,
    String? audioDuration,
  }) async {
    final id = await _engine.enqueue(
      sourceFile: sourceFile,
      destination: type == 'audio' ? MediaDestination.voice : MediaDestination.chat,
      type: type,
      folder: folder,
      caption: preview,
      preview: preview,
      chatId: chatId,
      fileName: fileName,
      mimeType: mimeType,
      audioDuration: audioDuration,
    );
    return id;
  }

  Future<Map<String, dynamic>?> getById(String id) => _engine.getById(id);

  Future<List<Map<String, dynamic>>> pendingForChat(String chatId) =>
      _engine.pendingForChat(chatId);

  Future<void> processPending() => _engine.processPending();

  Future<void> cancel(String id) => _engine.cancel(id);

  Future<void> retry(String id) => _engine.retry(id);

  Future<void> dispose() => _engine.dispose();
}
