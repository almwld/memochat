import 'package:flutter/material.dart';

/// Unified upload state indicator for chat media.
enum UploadStatus { uploading, sent, delivered, read, pending, failed }

class MediaUploadStatusWidget extends StatelessWidget {
  const MediaUploadStatusWidget({
    super.key,
    required this.status,
    this.progress = 0.0,
    this.onRetry,
    this.onCancel,
  });

  final UploadStatus status;
  final double progress;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    // Keep the state indicator inside the bubble, as in modern chat clients.
    return PositionedDirectional(end: 8, bottom: 5, child: _indicator());
  }

  Widget _indicator() {
    switch (status) {
      case UploadStatus.uploading:
        final double safeProgress = progress.clamp(0.0, 1.0).toDouble();
        return GestureDetector(
          onTap: onCancel,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  value: safeProgress,
                  strokeWidth: 2.2,
                  backgroundColor: Colors.black26,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.grey),
                ),
              ),
              const Icon(Icons.close, color: Colors.grey, size: 12),
            ],
          ),
        );
      case UploadStatus.sent:
        return const Icon(Icons.check_rounded, color: Color(0xFF667781), size: 15);
      case UploadStatus.delivered:
        return const Icon(Icons.done_all_rounded, color: Color(0xFF667781), size: 16);
      case UploadStatus.read:
        return const Icon(Icons.done_all_rounded, color: Color(0xFF53BDEB), size: 16);
      case UploadStatus.pending:
        return GestureDetector(
          onTap: onCancel,
          child: const Icon(Icons.schedule, color: Colors.grey, size: 15),
        );
      case UploadStatus.failed:
        return GestureDetector(
          onTap: onRetry,
          child: const Icon(Icons.refresh, color: Colors.red, size: 17),
        );
    }
  }
}
