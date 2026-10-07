import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:memochat/features/games/models/game.dart';
import 'package:memochat/features/games/models/game_session.dart';
import 'package:memochat/features/games/presentation/game_play_screen.dart';
import 'package:memochat/features/games/services/game_service.dart';
import 'game_factory.dart';

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
          if (game.status == GameStatus.playing) {
            final definition = ArcadeContentBank.forType(game.type);
            return GamePlayScreen(type: game.type, title: definition.title, chatId: widget.chatId, gameId: widget.gameId);
          }
          if (game.status == GameStatus.ended) {
            final uid = FirebaseAuth.instance.currentUser?.uid;
            final mine = uid == null ? 0 : (game.scores[uid] ?? 0);
            final best = game.scores.values.fold<int>(0, (a, b) => a > b ? a : b);
            final won = mine == best && best > 0;
            return Scaffold(
              appBar: AppBar(title: const Text('نتيجة اللعبة'), centerTitle: true),
              body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(won ? Icons.emoji_events_rounded : Icons.flag_rounded, size: 64),
                const SizedBox(height: 14),
                Text(won ? 'فزت!' : 'انتهت اللعبة', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text('نتيجتك: $mine نقطة', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                FilledButton.icon(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded), label: const Text('العودة للألعاب')),
              ])),),
            );
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
                    onPressed: uid == null ? null : () async { try { await GameService.instance.joinGame(chatId: widget.chatId, gameId: widget.gameId, uid: uid).timeout(const Duration(seconds: 8)); } catch (_) { if (!context.mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر الانضمام الآن. تحقق من الاتصال ثم حاول مجددًا.'))); } },
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