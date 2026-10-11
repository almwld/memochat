import 'classic_game_engine.dart';

class MovieQuizGame extends ClassicGameEngine {
  MovieQuizGame({super.key}) : super(config: const ClassicGameConfig(
    title: 'اختبار الأفلام',
    instruction: 'اقرأ السؤال واختر الإجابة الصحيحة',
    options: ['Inception', 'Avatar', 'Titanic', 'The Matrix'],
    correctIndex: 0,
    questions: [
      ClassicGameQuestion(prompt: 'أيّ فيلم من الخيارات يرتبط بالأحلام المتداخلة؟', options: ['Inception', 'Titanic', 'The Notebook', 'The King’s Speech'], correctIndex: 0),
      ClassicGameQuestion(prompt: 'أيّ فيلم تدور أحداثه حول سفينة ركاب شهيرة غرقت عام 1912؟', options: ['Avatar', 'Titanic', 'Inception', 'The Matrix'], correctIndex: 1),
      ClassicGameQuestion(prompt: 'أيّ فيلم تدور أحداثه على كوكب باندورا؟', options: ['The Matrix', 'Titanic', 'Avatar', 'Inception'], correctIndex: 2),
      ClassicGameQuestion(prompt: 'أيّ فيلم مشهور بعالم المحاكاة الرقمية المعروف باسم المصفوفة؟', options: ['Titanic', 'Avatar', 'Inception', 'The Matrix'], correctIndex: 3),
    ],
  ));
}
