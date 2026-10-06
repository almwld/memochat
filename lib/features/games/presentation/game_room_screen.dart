import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:memochat/features/games/models/game.dart';
import 'package:memochat/features/games/models/game_session.dart';
import 'package:memochat/features/games/presentation/game_play_screen.dart';
import 'package:memochat/features/games/services/game_service.dart';

class GameRoomScreen extends StatefulWidget {
  final String chatId;
  final String gameId;
  const GameRoomScreen({super.key, required this.chatId, required this.gameId});

  @override
  State<GameRoomScreen> createState() => _GameRoomScreenState();
}

class _GameRoomScreenState extends State<GameRoomScreen> {
  Timer? _networkGuard;

  @override
  void initState() {
    super.initState();
    _networkGuard = Timer(const Duration(seconds: 8), () { if (mounted) setState(() {}); });
  }

  @override
  void dispose() { _networkGuard?.cancel(); super.dispose(); }

  Widget _waiting() => const Center(child: Padding(padding: EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 18), Text('جاري فتح غرفة اللعبة…', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)), SizedBox(height: 8), Text('إذا كان VPN أو جدار الشبكة يمنع Firebase، لن تبقى الشاشة معلقة بلا تفسير.', textAlign: TextAlign.center)])));

  Widget _error(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off_rounded, size: 52), const SizedBox(height: 14), const Text('تعذر الاتصال بغرفة اللعبة', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), const SizedBox(height: 8), const Text('أوقف VPN مؤقتًا أو بدّل الشبكة ثم حاول مرة أخرى.', textAlign: TextAlign.center), const SizedBox(height: 14), OutlinedButton(onPressed: () => setState(() {}), child: const Text('إعادة المحاولة'))])));

  @override
  Widget build(BuildContext context) => StreamBuilder<GameSession?>(
        stream: GameService.instance.watchGame(widget.chatId, widget.gameId),
        builder: (context, snapshot) {
          final game = snapshot.data;

          if (snapshot.hasError) {
            return Scaffold(appBar: AppBar(title: const Text('غرفة اللعبة'), centerTitle: true), body: _error(context));
          }
          if (game == null && snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(appBar: AppBar(title: const Text('غرفة اللعبة'), centerTitle: true), body: _waiting());
          }
          if (game == null) return const Scaffold(body: Center(child: Text('لم تعد جلسة اللعبة متاحة.')));
          final uid = FirebaseAuth.instance.currentUser?.uid;
          final joined = uid != null && game.players.contains(uid);
          if (game.status == GameStatus.playing || game.status == GameStatus.ended) {
            final definition = game.type.name == 'xo' ? 'إكس أو' : 'لعبة ${game.type.name}';
            return GamePlayScreen(type: game.type, title: definition, chatId: widget.chatId, gameId: widget.gameId);
          }
          return Scaffold(
            appBar: AppBar(title: const Text('غرفة اللعبة'), centerTitle: true),
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.sports_esports_rounded, size: 54),
                  const SizedBox(height: 12),
                  Text(game.type.name == 'xo' ? 'إكس أو' : 'لعبة ${game.type.name}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text('${game.players.length} لاعبين'),
                  const SizedBox(height: 24),
                  if (!joined) FilledButton.icon(
                    onPressed: uid == null ? null : () => GameService.instance.joinGame(chatId: chatId, gameId: gameId, uid: uid),
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('انضم إلى اللعبة'),
                  ) else const Text('بانتظار لاعب آخر للبدء...'),
                ],
              ),
            ),
          );
        },
      );
}