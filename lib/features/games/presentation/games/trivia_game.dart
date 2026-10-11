import 'classic_game_engine.dart';

class TriviaGame extends ClassicGameEngine {
  TriviaGame({super.key}) : super(config: const ClassicGameConfig(
    title: 'تحدي المعلومات العامة',
    instruction: 'اقرأ السؤال ثم اختر الإجابة الصحيحة',
    options: ['المحيط الهادئ', 'المحيط الأطلسي', 'المحيط الهندي', 'المحيط المتجمد'],
    correctIndex: 0,
    questions: [
      ClassicGameQuestion(prompt: 'ما أكبر محيط في العالم؟', options: ['المحيط الهادئ', 'المحيط الأطلسي', 'المحيط الهندي', 'المحيط المتجمد'], correctIndex: 0),
      ClassicGameQuestion(prompt: 'ما اللغة الأساسية للقرآن الكريم؟', options: ['العربية', 'الإنجليزية', 'الفرنسية', 'الإسبانية'], correctIndex: 0),
      ClassicGameQuestion(prompt: 'كم ضلعًا للشكل السداسي؟', options: ['4', '5', '6', '8'], correctIndex: 2),
      ClassicGameQuestion(prompt: 'أيّ هذه الحيوانات من الثدييات؟', options: ['التمساح', 'الدلفين', 'السلحفاة', 'الضفدع'], correctIndex: 1),
      ClassicGameQuestion(prompt: 'ما عاصمة مصر؟', options: ['الإسكندرية', 'القاهرة', 'الأقصر', 'أسوان'], correctIndex: 1),
      ClassicGameQuestion(prompt: 'ما النجم الأقرب إلى الأرض؟', options: ['الشمس', 'الشعرى اليمانية', 'سيريوس', 'النجم القطبي'], correctIndex: 0),
    ],
  ));
}
