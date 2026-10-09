
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
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
    if (widget.isMe) return Colors.white;
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF53BDB0)
        : const Color(0xFF0D8274);
  }

  Color get _muted {
    if (widget.isMe) return Colors.white.withOpacity(.85);
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFD4E1DE)
        : const Color(0xFF263238);
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
        await _player.setUrl(value);
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
        const SizedBox(height: 1),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: PopupMenuButton<String>(
            tooltip: 'خيارات التسجيل الصوتي',
            icon: Icon(Icons.more_horiz_rounded, color: _muted, size: 20),
            padding: EdgeInsets.zero,
            onSelected: (action) {
              switch (action) {
                case 'back':
                  _seekBy(-10);
                  break;
                case 'forward':
                  _seekBy(10);
                  break;
                case 'speed':
                  _cycleSpeed();
                  break;
                case 'volume':
                  _toggleVolume();
                  break;
                case 'download':
                  _download();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'back', child: Text('رجوع 10 ثوان')),
              const PopupMenuItem(value: 'forward', child: Text('تقديم 10 ثوان')),
              PopupMenuItem(value: 'speed', child: Text('سرعة التشغيل: ${_speed}x')),
              PopupMenuItem(value: 'volume', child: Text(_volume == 0 ? 'تشغيل الصوت' : 'كتم الصوت')),
              if (!widget.isLocal)
                const PopupMenuItem(value: 'download', child: Text('تحميل التسجيل')),
            ],
          ),
        ),
      ]),
    );
  }

}
