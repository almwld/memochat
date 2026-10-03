import 'package:flutter/material.dart';

import 'advanced_audio_player.dart';

/// Backward-compatible audio bubble used by the chat message renderer.
/// The public API is preserved while the implementation now provides the
/// full advanced player controls (seek, speed, volume, loop and download).
class AudioWaveformBubble extends StatelessWidget {
  const AudioWaveformBubble({
    super.key,
    required this.audioUrl,
    required this.isMe,
    this.isLocal = false,
  });

  final String audioUrl;
  final bool isMe;
  final bool isLocal;

  @override
  Widget build(BuildContext context) {
    return AdvancedAudioPlayer(
      audioUrl: audioUrl,
      isMe: isMe,
      isLocal: isLocal,
    );
  }
}
