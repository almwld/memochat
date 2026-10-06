import 'package:flutter/widgets.dart';
import '../models/game.dart';
import 'runtime/memo_arcade_screen.dart';

/// Routes every catalog entry to the real interactive runtime.
/// Individual mechanics are selected from GameType instead of rendering quiz cards.
class DedicatedGameFactory {
  static Widget? build(GameType type) => MemoArcadeScreen(type: type);
}
