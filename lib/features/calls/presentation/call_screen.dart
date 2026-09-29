import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../../core/calls/livekit_call_service.dart';
import '../../../core/theme/app_icons.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({required this.serverUrl, required this.token, required this.title, super.key});
  final String serverUrl;
  final String token;
  final String title;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _service = LiveKitCallService();
  Room? _room;
  bool _connecting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    try {
      final room = await _service.connect(
        serverUrl: widget.serverUrl,
        token: widget.token,
        options: const RoomOptions(adaptiveStream: true, dynacast: true),
      );
      if (!mounted) {
        await room.disconnect();
        return;
      }
      setState(() {
        _room = room;
        _connecting = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    final room = _room;
    if (room != null) _service.disconnect(room);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1417),
      appBar: AppBar(title: Text(widget.title), backgroundColor: Colors.transparent),
      body: Center(
        child: _connecting
            ? const CircularProgressIndicator()
            : _error != null
                ? Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center))
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const AppIcon(AppIcons.videoCall, size: 72, color: Colors.white),
                      const SizedBox(height: 16),
                      Text('متصل بالمكالمة', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                      const SizedBox(height: 28),
                      FilledButton.tonalIcon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.call_end_rounded),
                        label: const Text('إنهاء المكالمة'),
                      ),
                    ],
                  ),
      ),
    );
  }
}
