import 'classic_game_engine.dart';

class GuessSongGame extends ClassicGameEngine {
  GuessSongGame({super.key}) : super(config: const ClassicGameConfig(
    title: 'تعرّف على النمط الموسيقي',
    instruction: 'اقرأ الوصف واختر النمط الموسيقي المناسب',
    options: ['جاز', 'روك', 'كلاسيكية', 'موسيقى إلكترونية'],
    correctIndex: 0,
    questions: [
      ClassicGameQuestion(prompt: 'أيّ نمط يشتهر بالارتجال واستخدام الساكسفون؟', options: ['جاز', 'روك', 'كلاسيكية', 'موسيقى إلكترونية'], correctIndex: 0),
      ClassicGameQuestion(prompt: 'أيّ نمط يرتبط غالبًا بالغيتار الكهربائي والإيقاع القوي؟', options: ['كلاسيكية', 'روك', 'جاز', 'إنشاد'], correctIndex: 1),
      ClassicGameQuestion(prompt: 'أيّ نمط يرتبط بالأوركسترا والسيمفونيات؟', options: ['هيب هوب', 'روك', 'كلاسيكية', 'جاز'], correctIndex: 2),
      ClassicGameQuestion(prompt: 'أيّ نمط يُنتَج غالبًا باستخدام المُركِّبات الصوتية والإيقاعات المُبرمجة؟', options: ['جاز', 'شعبية', 'كلاسيكية', 'موسيقى إلكترونية'], correctIndex: 3),
    ],
  ));
}
