import 'package:flutter_test/flutter_test.dart';
import 'package:memochat/features/games/models/game.dart';
import 'package:memochat/features/games/presentation/runtime/arcade_content.dart';

void main() {
  test('arcade content covers every game type exactly once', () {
    expect(ArcadeContentBank.all.length, GameType.values.length);
    expect(
      ArcadeContentBank.all.map((item) => item.type).toSet(),
      containsAll(GameType.values),
    );
    expect(
      ArcadeContentBank.all.map((item) => item.type).toSet().length,
      ArcadeContentBank.all.length,
    );
  });

  test('every quiz prompt has aligned, understandable answer choices', () {
    final quizzes = ArcadeContentBank.all
        .where((item) => item.mode == ArcadeMode.quiz);

    expect(quizzes, isNotEmpty);
    for (final quiz in quizzes) {
      expect(quiz.prompts, isNotEmpty, reason: '${quiz.type.name} needs questions');
      expect(
        quiz.prompts.every((prompt) => prompt.trim().isNotEmpty),
        isTrue,
        reason: '${quiz.type.name} contains an empty question',
      );
      expect(
        quiz.choicesByPrompt.length,
        quiz.prompts.length,
        reason: '${quiz.type.name} must provide choices for every question',
      );
      expect(
        quiz.correctAnswers.length,
        quiz.prompts.length,
        reason: '${quiz.type.name} must provide an answer key for every question',
      );

      for (var i = 0; i < quiz.prompts.length; i++) {
        final choices = quiz.choicesByPrompt[i];
        expect(choices.length, inInclusiveRange(2, 4),
            reason: '${quiz.type.name} question $i has an invalid number of choices');
        expect(choices.every((choice) => choice.trim().isNotEmpty), isTrue,
            reason: '${quiz.type.name} question $i has an empty choice');
        expect(choices.toSet().length, choices.length,
            reason: '${quiz.type.name} question $i repeats a choice');
        expect(quiz.correctAnswers[i], inInclusiveRange(0, choices.length - 1),
            reason: '${quiz.type.name} question $i has an invalid answer index');
      }
    }
  });

  test('every content item has readable title and instructions', () {
    for (final item in ArcadeContentBank.all) {
      expect(item.title.trim(), isNotEmpty, reason: item.type.name);
      expect(item.instruction.trim(), isNotEmpty, reason: item.type.name);
      expect(item.prompts.every((prompt) => prompt.trim().isNotEmpty), isTrue,
          reason: '${item.type.name} has a blank prompt');
      if (item.correctAnswers.isNotEmpty) {
        expect(item.correctAnswers.length, item.prompts.length,
            reason: '${item.type.name} answer count does not match prompt count');
      }
    }
  });
}
