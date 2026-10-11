import 'package:flutter_test/flutter_test.dart';
import 'package:memochat/features/games/models/game.dart';
import 'package:memochat/features/games/presentation/runtime/arcade_content.dart';

void main() {
  group('ArcadeContentBank', () {
    test('contains every game type exactly once', () {
      expect(ArcadeContentBank.all.length, GameType.values.length);
      expect(
        ArcadeContentBank.all.map((item) => item.type).toSet().length,
        GameType.values.length,
      );
      expect(
        ArcadeContentBank.all.map((item) => item.type),
        containsAll(GameType.values),
      );
    });

    test('every quiz has a clear prompt, choices, and a valid answer index', () {
      final quizzes = ArcadeContentBank.all
          .where((item) => item.mode == ArcadeMode.quiz)
          .toList();
      expect(quizzes, isNotEmpty);

      for (final quiz in quizzes) {
        expect(quiz.prompts, isNotEmpty, reason: '${quiz.type.name} has no questions');
        expect(
          quiz.correctAnswers.length,
          quiz.prompts.length,
          reason: '${quiz.type.name} must define one answer per question',
        );
        expect(
          quiz.choicesByPrompt.length,
          quiz.prompts.length,
          reason: '${quiz.type.name} must define choices for every question',
        );

        for (var i = 0; i < quiz.prompts.length; i++) {
          expect(quiz.prompts[i].trim(), isNotEmpty);
          final options = quiz.choicesByPrompt[i];
          expect(options.length, inInclusiveRange(2, 4));
          expect(options.every((option) => option.trim().isNotEmpty), isTrue);
          expect(
            quiz.correctAnswers[i],
            inInclusiveRange(0, options.length - 1),
            reason: '${quiz.type.name} question $i has an invalid answer index',
          );
        }
      }
    });

    test('choice-based preference games have round prompts and valid option sets', () {
      for (final type in [
        GameType.drawGuess,
        GameType.truthDare,
        GameType.wouldYouRather,
      ]) {
        final content = ArcadeContentBank.forType(type);
        expect(content.prompts, isNotEmpty, reason: '${type.name} needs prompts');
        expect(content.options.length, greaterThanOrEqualTo(2));
        expect(content.prompts.every((prompt) => prompt.trim().isNotEmpty), isTrue);
      }

      final preferenceGame = ArcadeContentBank.forType(GameType.wouldYouRather);
      expect(preferenceGame.choicesByPrompt.length, preferenceGame.prompts.length);
      expect(
        preferenceGame.choicesByPrompt.every((options) => options.length == 2),
        isTrue,
      );
    });

    test('word scramble rounds use real words rather than already scrambled prompts', () {
      final content = ArcadeContentBank.forType(GameType.anagramBattle);
      expect(content.prompts, ['مدرسة', 'كتاب', 'هاتف']);
      expect(content.prompts.toSet().length, content.prompts.length);
    });
  });
}
