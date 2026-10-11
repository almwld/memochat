import 'classic_game_engine.dart';

class QuizBattleGame extends ClassicGameEngine {
  QuizBattleGame({super.key}) : super(config: const ClassicGameConfig(
    title: 'تحدي المعلومات',
    instruction: 'اقرأ السؤال واختر الإجابة الصحيحة',
    options: ['المريخ', 'الزهرة', 'الأرض', 'المشتري'],
    correctIndex: 0,
    questions: [
      ClassicGameQuestion(prompt: 'ما الكوكب المعروف بلونه الأحمر؟', options: ['المريخ', 'الزهرة', 'الأرض', 'المشتري'], correctIndex: 0),
      ClassicGameQuestion(prompt: 'ما عاصمة اليمن؟', options: ['عدن', 'صنعاء', 'تعز', 'الحديدة'], correctIndex: 1),
      ClassicGameQuestion(prompt: 'كم ضلعًا للمثلث؟', options: ['2', '3', '4', '5'], correctIndex: 1),
      ClassicGameQuestion(prompt: 'ما أكبر محيط في العالم؟', options: ['المحيط الأطلسي', 'المحيط الهادئ', 'المحيط الهندي', 'المحيط المتجمد'], correctIndex: 1),
      ClassicGameQuestion(prompt: 'ما الصيغة الكيميائية للماء؟', options: ['CO₂', 'H₂O', 'O₂', 'NaCl'], correctIndex: 1),
      ClassicGameQuestion(prompt: 'كم يومًا في الأسبوع؟', options: ['5', '6', '7', '8'], correctIndex: 2),
      ClassicGameQuestion(prompt: 'ما أكبر قارات العالم مساحةً؟', options: ['أفريقيا', 'آسيا', 'أوروبا', 'أمريكا الجنوبية'], correctIndex: 1),
      ClassicGameQuestion(prompt: 'ما جمع كلمة «كتاب»؟', options: ['كاتب', 'كتابان', 'كتب', 'مكتبة'], correctIndex: 2),
    ],
  ));
}
