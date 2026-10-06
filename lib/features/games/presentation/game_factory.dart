import 'package:flutter/widgets.dart';
import '../models/game.dart';
import 'runtime/memo_arcade_screen.dart';

class DedicatedGameFactory {
  static Widget? build(GameType type, {String chatId = '', String? gameId}) =>
      MemoArcadeScreen(type: type, chatId: chatId, gameId: gameId);
}
