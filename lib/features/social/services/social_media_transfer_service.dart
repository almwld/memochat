import 'dart:async';
import 'dart:io';

import '../../../core/media/media_transfer_engine.dart';

const socialMediaTransferTask = mediaTransferTask;

@pragma('vm:entry-point')
void socialMediaTransferCallbackDispatcher() {
  mediaTransferCallbackDispatcher();
}

class SocialMediaTransferService {
  SocialMediaTransferService._();
  static final instance = SocialMediaTransferService._();

  final _engine = MediaTransferEngine.instance;

  Future<void> initialize({bool startWorker = true}) =>
      _engine.initialize(startWorker: startWorker);

  Future<String> enqueue({
    required File sourceFile,
    required String collection,
    required String type,
    required String caption,
    String? fileName,
    String? mimeType,
  }) {
    if (collection != 'socialPosts' && collection != 'socialReels') {
      throw ArgumentError('مجموعة اجتماعية غير مدعومة');
    }
    return _engine.enqueue(
      sourceFile: sourceFile,
      destination: collection == 'socialReels'
          ? MediaDestination.socialReel
          : MediaDestination.socialPost,
      type: type,
      folder: collection,
      caption: caption,
      preview: caption,
      collectionName: collection,
      fileName: fileName,
      mimeType: mimeType,
    );
  }

  Future<void> processPending() => _engine.processPending();

  Future<void> cancel(String id) => _engine.cancel(id);

  Future<void> retry(String id) => _engine.retry(id);

  Future<void> dispose() => _engine.dispose();
}
