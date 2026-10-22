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
            options.toSet().length,
            options.length,
            reason: 'Each quiz question must have distinct choices',
          );
          expect(
            quiz.prompts[i],
            isNot(anyOf('اختر الإجابة الصحيحة', 'اختر أحد الخيارات', 'اختر')),
            reason: 'Each quiz prompt must say what the player is answering',
          );
          expect(
            quiz.prompts[i],
            isNot(contains('اختر أربعة')),
            reason: 'Quiz runtime supports one answer per tap, not multi-select',
          );
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
        final choices = content.choicesByPrompt.isNotEmpty
            ? content.choicesByPrompt.first
            : content.options;
        expect(choices.length, greaterThanOrEqualTo(2));
        expect(content.prompts.every((prompt) => prompt.trim().isNotEmpty), isTrue);
      }

      final preferenceGame = ArcadeContentBank.forType(GameType.wouldYouRather);
      expect(preferenceGame.choicesByPrompt.length, preferenceGame.prompts.length);
      expect(
        preferenceGame.choicesByPrompt.every((options) => options.length == 2),
        isTrue,
      );
    });


    test('known quiz answers point to the correct option, not just a valid index', () {
      const expectedAnswers = <GameType, List<String>>{
        GameType.quizBattle: ['المريخ', '7', 'صنعاء', '3'],
        GameType.trivia: ['الهادئ', 'العربية', '7'],
        GameType.trueFalse: ['صحيح', 'خطأ', 'صحيح'],
        GameType.emojiReaction: ['❤', '★', '●', '◆'],
        GameType.guessSong: ['جاز', 'روك', 'كلاسيكي', 'عربي'],
        GameType.movieQuiz: ['أكشن', 'كوميديا', 'خيال علمي', 'دراما'],
        GameType.higherLower: ['18', '23', 'متساويان', '31'],
        GameType.flagQuiz: ['اليمن', 'اليابان', 'فرنسا'],
        GameType.animalQuiz: ['الفهد', 'الحوت الأزرق'],
        GameType.foodQuiz: ['سوشي', 'كبسة', 'بيتزا', 'الحمص'],
        GameType.geographyQuiz: ['إيفرست', 'آسيا'],
        GameType.scienceQuiz: ['H₂O', 'إلكترون'],
        GameType.historyQuiz: ['اليمن', 'مصر'],
        GameType.languageQuiz: ['كتب', 'صغير'],
      };

      for (final entry in expectedAnswers.entries) {
        final content = ArcadeContentBank.forType(entry.key);
        expect(entry.value.length, content.prompts.length,
            reason: '${entry.key.name} expected-answer fixture is out of sync');
        for (var i = 0; i < entry.value.length; i++) {
          final options = content.choicesByPrompt[i];
          expect(
            options[content.correctAnswers[i]],
            entry.value[i],
            reason: '${entry.key.name} question $i marks the wrong answer',
          );
        }
      }
    });

    test('word scramble rounds use real words rather than already scrambled prompts', () {
      final content = ArcadeContentBank.forType(GameType.anagramBattle);
      expect(content.prompts, ['مدرسة', 'كتاب', 'هاتف']);
      expect(content.prompts.toSet().length, content.prompts.length);
    });
  });
}
