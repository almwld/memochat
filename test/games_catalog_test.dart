import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memochat/features/games/data/games_catalog.dart';
import 'package:memochat/features/games/models/game.dart';
import 'package:memochat/features/games/presentation/game_factory.dart';

void main() {
  test('games catalog contains all 55 game types exactly once', () {
    expect(GamesCatalog.all.length, 55);
    expect(GamesCatalog.all.map((e) => e.type).toSet().length, 55);
    expect(GamesCatalog.all.map((e) => e.type), containsAll(GameType.values));
  });

  test('every catalog entry has usable presentation metadata', () {
    for (final game in GamesCatalog.all) {
      expect(game.title.trim(), isNotEmpty);
      expect(game.subtitle.trim(), isNotEmpty);
      expect(game.playersLabel.trim(), isNotEmpty);
      expect(game.minPlayers, greaterThanOrEqualTo(1));
      expect(game.maxPlayers, greaterThanOrEqualTo(game.minPlayers));
    }
  });

  test('every game type resolves to a playable widget', () {
    for (final type in GameType.values) {
      final widget = DedicatedGameFactory.build(type);
      expect(widget, isA<Widget>(), reason: 'Missing renderer for ${type.name}');
    }
  });
}
