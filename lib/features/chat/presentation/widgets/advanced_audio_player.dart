
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/media/local_media_cache.dart';
import 'package:url_launcher/url_launcher.dart';

/// Compact in-bubble voice-message player.
/// Controls stay inside the message bubble; normal playback actions never open
/// a modal sheet, keeping the interaction close to WhatsApp/Telegram voice notes.
class AdvancedAudioPlayer extends StatefulWidget {
  const AdvancedAudioPlayer({super.key, required this.audioUrl, required this.isMe, this.isLocal = false, this.title});

  final String audioUrl;
  final bool isMe;
  final bool isLocal;
  final String? title;

  @override
  State<AdvancedAudioPlayer> createState() => _AdvancedAudioPlayerState();
}

class _AdvancedAudioPlayerState extends State<AdvancedAudioPlayer> {
  late final AudioPlayer _player;
  static const _speeds = <double>[1.0, 1.5, 2.0, 0.75];
  double _speed = 1.0;
  double _volume = 1.0;
  bool _loading = true;
  bool _error = false;

  static AudioPlayer? _activePlayer;

  Color get _foreground {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF53BDEB)
        : const Color(0xFF075E54);
  }

  Color get _muted {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFD4E1DE)
        : const Color(0xFF667781);
  }

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      final value = widget.audioUrl.trim();
      if (value.isEmpty) throw StateError('empty audio url');
      if (widget.isLocal || value.startsWith('file://')) {
        final path = value.startsWith('file://') ? Uri.parse(value).toFilePath() : value;
        await _player.setFilePath(path);
      } else {
        final cached = await LocalMediaCache.instance.existing(value);
        if (cached != null) {
          await _player.setFilePath(cached.path);
        } else {
          await _player.setUrl(value);
          LocalMediaCache.instance.getOrDownload(value);
        }
      }
      await _player.setVolume(_volume);
      await _player.setSpeed(_speed);
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      debugPrint('AdvancedAudioPlayer prepare error: $e');
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  @override
  void didUpdateWidget(covariant AdvancedAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioUrl != widget.audioUrl || oldWidget.isLocal != widget.isLocal) {
      _loading = true;
      _error = false;
      _prepare();
    }
  }

  @override
  void dispose() {
    if (identical(_activePlayer, _player)) _activePlayer = null;
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_loading) return;
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
      await _player.play();
    } else if (_player.playing) {
      await _player.pause();
    } else {
      final previous = _activePlayer;
      if (previous != null && !identical(previous, _player)) {
        await previous.pause();
      }
      _activePlayer = _player;
      await _player.play();
    }
  }

  Future<void> _seekBy(int seconds) async {
    var target = _player.position + Duration(seconds: seconds);
    final duration = _player.duration ?? Duration.zero;
    if (target < Duration.zero) target = Duration.zero;
    if (duration > Duration.zero && target > duration) target = duration;
    await _player.seek(target);
  }

  Future<void> _cycleSpeed() async {
    final index = _speeds.indexOf(_speed);
    final next = _speeds[(index + 1) % _speeds.length];
    await _player.setSpeed(next);
    if (mounted) setState(() => _speed = next);
  }

  Future<void> _toggleVolume() async {
    final next = _volume == 0 ? 1.0 : 0.0;
    await _player.setVolume(next);
    if (mounted) setState(() => _volume = next);
  }

  Future<void> _download() async {
    if (widget.isLocal) return;
    final uri = Uri.tryParse(widget.audioUrl);
    if (uri != null && uri.hasScheme && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _format(Duration value) {
    final total = value.inSeconds;
    return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
  }

  Widget _compactControl({
    required IconData icon,
    required String tooltip,
    required Future<void> Function() onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        radius: 15,
        onTap: () => onPressed(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: Icon(icon, size: 16, color: _muted),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline_rounded, color: _foreground, size: 18),
          const SizedBox(width: 7),
          Text('تعذر تشغيل التسجيل', style: TextStyle(color: _foreground, fontSize: 12)),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(7, 6, 7, 5),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (widget.title != null && widget.title!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(children: [
              Icon(Icons.mic_rounded, size: 14, color: _muted),
              const SizedBox(width: 5),
              Expanded(child: Text(widget.title!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w600))),
            ]),
          ),
        Row(children: [
          StreamBuilder<PlayerState>(
            stream: _player.playerStateStream,
            builder: (context, snapshot) {
              final state = snapshot.data;
              final busy = _loading || state?.processingState == ProcessingState.loading || state?.processingState == ProcessingState.buffering;
              final playing = state?.playing == true;
              return Material(
                color: _foreground.withOpacity(.12),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: busy ? null : _togglePlay,
                  child: SizedBox(width: 38, height: 38, child: Center(child: busy
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _foreground))
                      : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: _foreground, size: 23))),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Expanded(child: StreamBuilder<Duration?>(
            stream: _player.durationStream,
            builder: (context, durationSnapshot) {
              final duration = durationSnapshot.data ?? Duration.zero;
              return StreamBuilder<Duration>(
                stream: _player.positionStream,
                builder: (context, positionSnapshot) {
                  final position = positionSnapshot.data ?? Duration.zero;
                  final max = duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0;
                  final value = position.inMilliseconds.clamp(0, max.toInt()).toDouble();
                  return Column(children: [
                    SizedBox(height: 20, child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(activeTrackColor: _foreground, inactiveTrackColor: _foreground.withOpacity(.22), thumbColor: _foreground, overlayColor: Colors.transparent, trackHeight: 2.5, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4)),
                      child: Slider(value: value, min: 0, max: max, onChanged: _loading ? null : (v) => _player.seek(Duration(milliseconds: v.round()))),
                    )),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(_format(position), style: TextStyle(color: _muted, fontSize: 9)),
                      Text(_format(duration), style: TextStyle(color: _muted, fontSize: 9)),
                    ]),
                  ]);
                },
              );
            },
          )),
        ]),
        const SizedBox(height: 2),
        // Direct, compact controls replace the oversized three-dot menu.
        // Small fixed tap targets keep the voice bubble close to normal size.
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _compactControl(
              icon: Icons.replay_10_rounded,
              tooltip: 'رجوع 10 ثوان',
              onPressed: () => _seekBy(-10),
            ),
            _compactControl(
              icon: Icons.forward_10_rounded,
              tooltip: 'تقديم 10 ثوان',
              onPressed: () => _seekBy(10),
            ),
            InkWell(
              onTap: _cycleSpeed,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  '${_speed}x',
                  style: TextStyle(
                    color: _foreground,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            _compactControl(
              icon: _volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              tooltip: _volume == 0 ? 'تشغيل الصوت' : 'كتم الصوت',
              onPressed: _toggleVolume,
            ),
            if (!widget.isLocal)
              _compactControl(
                icon: Icons.download_rounded,
                tooltip: 'تحميل التسجيل',
                onPressed: _download,
              ),
          ],
        ),
      ]),
    );
  }

}
