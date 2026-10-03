import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:memochat/features/games/models/game.dart';
import 'package:memochat/features/games/models/game_session.dart';
import 'package:memochat/features/games/presentation/game_play_screen.dart';
import 'package:memochat/features/games/services/game_service.dart';

class GameRoomScreen extends StatelessWidget {
  final String chatId;
  final String gameId;
  const GameRoomScreen({super.key, required this.chatId, required this.gameId});

  @override
  Widget build(BuildContext context) => StreamBuilder<GameSession?>(
        stream: GameService.instance.watchGame(chatId, gameId),
        builder: (context, snapshot) {
          final game = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (game == null) return const Scaffold(body: Center(child: Text('لم تعد جلسة اللعبة متاحة.')));
          final uid = FirebaseAuth.instance.currentUser?.uid;
          final joined = uid != null && game.players.contains(uid);
          if (game.status == GameStatus.playing || game.status == GameStatus.ended) {
            final definition = game.type.name == 'xo' ? 'إكس أو' : 'لعبة ${game.type.name}';
            return GamePlayScreen(type: game.type, title: definition, chatId: chatId);
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