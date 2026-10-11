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
        GameType.emojiReaction: ['❤', '★', '●', '◆'],
        GameType.trivia: ['الهادئ', 'العربية', '7', '12', 'الأكسجين', '6'],
        GameType.fastChoice: ['13', '4', 'صنعاء', '60'],
        GameType.trueFalse: ['صحيح', 'خطأ', 'صحيح'],
        GameType.riddleRush: ['المشط', 'الوقت', 'الحفرة', 'الكتاب', 'الصدى'],
        GameType.guessSong: ['جاز', 'روك', 'كلاسيكي', 'عربي'],
        GameType.movieQuiz: ['أكشن', 'كوميديا', 'خيال علمي', 'دراما'],
        GameType.higherLower: ['18', '23', 'متساويان', '31', '9', 'لا'],
        GameType.flagQuiz: ['اليمن', 'اليابان', 'فرنسا', 'البرازيل', 'مصر', 'إيطاليا'],
        GameType.animalQuiz: ['الفهد', 'الحوت الأزرق', 'خلد الماء', 'الحمار الوحشي', 'الدهون'],
        GameType.foodQuiz: ['سوشي', 'كبسة', 'بيتزا', 'الحمص'],
        GameType.geographyQuiz: ['إيفرست', 'آسيا', 'طوكيو', 'المحيط الهندي', 'أفريقيا'],
        GameType.scienceQuiz: ['H₂O', 'إلكترون', 'البناء الضوئي', 'الشمس', '0°م'],
        GameType.historyQuiz: ['اليمن', 'مصر', 'روما', 'نيل أرمسترونغ', 'الصين'],
        GameType.languageQuiz: ['كتب', 'صغير', 'ماضٍ', 'طالبان', 'مدرسة'],
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
