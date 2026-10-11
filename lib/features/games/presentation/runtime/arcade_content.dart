import '../../models/game.dart';

enum ArcadeMode {
  target,
  memory,
  color,
  sequence,
  timing,
  explorer,
  quiz,
  math,
  word,
  code,
  lights,
  pairs,
  race,
  choice,
  oddOneOut,
}

class ArcadeContent {
  final GameType type;
  final String title;
  final String instruction;
  final ArcadeMode mode;
  final List<String> prompts;
  final List<String> options;
  final List<int> correctAnswers;
  final List<List<String>> choicesByPrompt;

  const ArcadeContent({
    required this.type,
    required this.title,
    required this.instruction,
    required this.mode,
    this.prompts = const [],
    this.options = const [],
    this.correctAnswers = const [],
    this.choicesByPrompt = const [],
  });
}

class ArcadeContentBank {
  static const List<ArcadeContent> all = [
    ArcadeContent(type: GameType.xo, title: 'إكس أو', instruction: 'ضع علامتك بالتناوب', mode: ArcadeMode.choice, options: ['X','O']),
    ArcadeContent(type: GameType.quizBattle, title: 'معركة المعلومات', instruction: 'اختر الإجابة الصحيحة', mode: ArcadeMode.quiz, prompts: ['ما هو الكوكب الأحمر؟','كم عدد قارات العالم؟','ما عاصمة اليمن؟','كم ضلعًا للمثلث؟'], options: ['المريخ','الأرض','آسيا','سبعة','صنعاء','عدن','3','4'], correctAnswers: [0,0,0,0], choicesByPrompt: [['المريخ','الزهرة','الأرض','المشتري'],['7','5','6','8'],['صنعاء','عدن','تعز','الحديدة'],['3','4','5','6']]),
    ArcadeContent(type: GameType.emojiReaction, title: 'تحدي سرعة الرموز', instruction: 'اقرأ المطلوب واضغط الرمز المطابق', mode: ArcadeMode.quiz, prompts: ['اختر رمز القلب','اختر رمز النجمة','اختر الدائرة','اختر المعين'], correctAnswers: [0,0,0,0], choicesByPrompt: [['❤','★','●','◆'],['★','❤','◆','●'],['●','◆','❤','★'],['◆','●','★','❤']]),
    ArcadeContent(type: GameType.diceRoll, title: 'Dice Roll', instruction: 'ارمِ النرد واجمع أعلى مجموع', mode: ArcadeMode.timing),
    ArcadeContent(type: GameType.drawGuess, title: 'ارسم وخمّن', instruction: 'اختر كلمة بسيطة للجولة', mode: ArcadeMode.choice, prompts: ['اختر كلمة للجولة الأولى','اختر كلمة جديدة للجولة التالية','اختر شيئًا من الطبيعة','اختر شيئًا يمكن رسمه بسهولة'], options: ['بيت','شمس','قمر','سيارة']),
    ArcadeContent(type: GameType.wordChain, title: 'Word Chain', instruction: 'كوّن كلمة تبدأ بآخر حرف', mode: ArcadeMode.word, prompts: ['كتاب','باب','بحر','ربيع']),
    ArcadeContent(type: GameType.truthDare, title: 'صراحة أم تحدٍ؟', instruction: 'اختر نوع الجولة ثم التزم بتحدٍ آمن ومحترم', mode: ArcadeMode.choice, prompts: ['هل تريد الإجابة عن سؤال صريح أم تنفيذ تحدٍ؟','اختر طريقة الجولة التالية','هل تفضّل سؤالًا أم مهمة مرحة؟'], options: ['صراحة','تحدٍ']),
    ArcadeContent(type: GameType.guessSong, title: 'خمن النمط الموسيقي', instruction: 'اقرأ الوصف واختر النمط الأنسب', mode: ArcadeMode.quiz, prompts: ['أي نمط يشتهر بالارتجال والساكسفون؟','أي نمط يرتبط غالبًا بالغيتار الكهربائي والإيقاع القوي؟','أي نمط يضم مؤلفات أوركسترالية مثل السيمفونيات؟','ما الاسم العام للأغاني المنتشرة باللهجات العربية؟'], correctAnswers: [0,2,2,3], choicesByPrompt: [['جاز','روك','كلاسيكي','بوب'],['كلاسيكي','جاز','روك','بوب'],['بوب','روك','كلاسيكي','جاز'],['جاز','كلاسيكي','روك','عربي']]),
    ArcadeContent(type: GameType.memoryMatch, title: 'Memory Match', instruction: 'اعثر على الأزواج المتطابقة', mode: ArcadeMode.memory),
    ArcadeContent(type: GameType.trivia, title: 'تحدي المعلومات', instruction: 'أجب عن السؤال قبل انتهاء الوقت', mode: ArcadeMode.quiz, prompts: ['ما أكبر محيط في العالم؟','ما اللغة التي نزل بها القرآن الكريم؟','كم يومًا في الأسبوع؟'], options: ['الهادئ','العربية','7'], correctAnswers: [0,0,0], choicesByPrompt: [['الهادئ','الأطلسي','الهندي','المتجمد'],['العربية','الإنجليزية','الفرنسية','الإسبانية'],['7','5','6','8']]),
    ArcadeContent(type: GameType.quickTap, title: 'Quick Tap', instruction: 'اضغط الأهداف بسرعة', mode: ArcadeMode.target),
    ArcadeContent(type: GameType.wouldYouRather, title: 'ماذا تفضّل؟', instruction: 'اختر تفضيلك ولا توجد إجابة خاطئة', mode: ArcadeMode.choice, prompts: ['أيهما تختار لو أتيحت لك الفرصة؟','ما التجربة التي تفضّلها في الجولة التالية؟','أي خيار أقرب إلى شخصيتك؟'], choicesByPrompt: [['السفر للماضي','السفر للمستقبل'],['العيش قرب البحر','العيش قرب الجبال'],['قراءة الأفكار','الاختفاء لدقيقة']]),
    ArcadeContent(type: GameType.speedMath, title: 'Speed Math', instruction: 'حل المسألة بسرعة', mode: ArcadeMode.math),
    ArcadeContent(type: GameType.movieQuiz, title: 'اختبار الأفلام', instruction: 'اختر النوع الذي يطابق الوصف', mode: ArcadeMode.quiz, prompts: ['مطاردات ومعارك ومشاهد حركة كثيرة: أي نوع؟','مواقف مضحكة هدفها إضحاك المشاهد: أي نوع؟','أحداث عن الفضاء وتقنيات مستقبلية متخيلة: أي نوع؟','قصة تركز على المشاعر والعلاقات الإنسانية: أي نوع؟'], correctAnswers: [0,1,0,0], choicesByPrompt: [['أكشن','كوميديا','خيال علمي','دراما'],['دراما','كوميديا','أكشن','وثائقي'],['خيال علمي','أكشن','رومانسي','كوميديا'],['دراما','خيال علمي','أكشن','كرتون']]),
    ArcadeContent(type: GameType.sudokuDuel, title: 'Sudoku Duel', instruction: 'أكمل شبكة 4×4', mode: ArcadeMode.pairs),
    ArcadeContent(type: GameType.colorRush, title: 'Color Rush', instruction: 'اضغط اللون المطلوب', mode: ArcadeMode.color),
    ArcadeContent(type: GameType.higherLower, title: 'الأعلى أم الأقل؟', instruction: 'قارن العددين واختر الأكبر أو متساويان', mode: ArcadeMode.quiz, prompts: ['أي العددين أكبر: 18 أم 12؟','أي العددين أكبر: 7 أم 23؟','هل العددان متساويان: 45 و45؟','أي العددين أكبر: 31 أم 19؟'], correctAnswers: [0,1,2,0], choicesByPrompt: [['18','12','متساويان'],['7','23','متساويان'],['45','45','متساويان'],['31','19','متساويان']]),
    ArcadeContent(type: GameType.numberGuess, title: 'Number Guess', instruction: 'اقترب من الرقم السري', mode: ArcadeMode.math),
    ArcadeContent(type: GameType.wordScramble, title: 'Word Scramble', instruction: 'رتب الحروف لتكوين الكلمة', mode: ArcadeMode.word, prompts: ['كتاب','مدرسة','هاتف','شجرة']),
    ArcadeContent(type: GameType.emojiMemory, title: 'Emoji Memory', instruction: 'تذكر ترتيب الرموز', mode: ArcadeMode.memory),
    ArcadeContent(type: GameType.patternTap, title: 'Pattern Tap', instruction: 'اتبع التسلسل الصحيح', mode: ArcadeMode.sequence),
    ArcadeContent(type: GameType.oddOneOut, title: 'Odd One Out', instruction: 'اعثر على العنصر المختلف', mode: ArcadeMode.oddOneOut),
    ArcadeContent(type: GameType.fourInRow, title: 'Four in a Row', instruction: 'كوّن أربعة متتالية', mode: ArcadeMode.pairs),
    ArcadeContent(type: GameType.dotsAndBoxes, title: 'Dots & Boxes', instruction: 'أكمل المربعات بوصل النقاط', mode: ArcadeMode.pairs),
    ArcadeContent(type: GameType.reactionRace, title: 'Reaction Race', instruction: 'استجب لحظة ظهور الإشارة', mode: ArcadeMode.timing),
    ArcadeContent(type: GameType.cardFlip, title: 'Card Flip', instruction: 'اقلب البطاقات واعثر على الأزواج', mode: ArcadeMode.memory),
    ArcadeContent(type: GameType.treasureHunt, title: 'Treasure Hunt', instruction: 'ابحث عن الكنز قبل اختفائه', mode: ArcadeMode.explorer),
    ArcadeContent(type: GameType.mazeRunner, title: 'Maze Runner', instruction: 'اتبع العلامات داخل المتاهة', mode: ArcadeMode.explorer),
    ArcadeContent(type: GameType.stackTower, title: 'Stack Tower', instruction: 'اضغط في اللحظة المثالية', mode: ArcadeMode.timing),
    ArcadeContent(type: GameType.targetHit, title: 'Target Hit', instruction: 'أصب الهدف المتحرك', mode: ArcadeMode.target),
    ArcadeContent(type: GameType.bubblePop, title: 'Bubble Pop', instruction: 'فرقع أكبر عدد من الفقاعات', mode: ArcadeMode.target),
    ArcadeContent(type: GameType.colorMatch, title: 'Color Match', instruction: 'طابق اللون مع الهدف', mode: ArcadeMode.color),
    ArcadeContent(type: GameType.shapeMatch, title: 'Shape Match', instruction: 'اضغط الشكل المطابق', mode: ArcadeMode.sequence),
    ArcadeContent(type: GameType.sequenceRecall, title: 'Sequence Recall', instruction: 'كرر التسلسل بالترتيب', mode: ArcadeMode.sequence),
    ArcadeContent(type: GameType.fastChoice, title: 'الاختيار السريع', instruction: 'أجب عن السؤال بأسرع ما يمكن', mode: ArcadeMode.quiz, prompts: ['كم يساوي 6 + 7؟','كم ضلعًا للمربع؟','ما عاصمة اليمن؟','كم دقيقة في الساعة؟'], correctAnswers: [1,0,2,3], choicesByPrompt: [['11','13','12','14'],['4','3','5','6'],['عدن','تعز','صنعاء','إب'],['30','45','50','60']]),
    ArcadeContent(type: GameType.trueFalse, title: 'صح أم خطأ', instruction: 'احكم على العبارة', mode: ArcadeMode.quiz, prompts: ['الماء يغلي عند 100°م.','الشمس كوكب.','اليمن في آسيا.'], options: ['صحيح','خطأ'], correctAnswers: [0,1,0], choicesByPrompt: [['صحيح','خطأ'],['صحيح','خطأ'],['صحيح','خطأ']]),
    ArcadeContent(type: GameType.flagQuiz, title: 'اختبار الأعلام', instruction: 'اختر الدولة التي ينتمي إليها العلم', mode: ArcadeMode.quiz, prompts: ['🇾🇪','🇯🇵','🇫🇷'], options: ['اليمن','اليابان','فرنسا'], correctAnswers: [0,0,0], choicesByPrompt: [['اليمن','اليابان','فرنسا','مصر'],['اليابان','الصين','كوريا','تايلاند'],['فرنسا','إيطاليا','بلجيكا','هولندا']]),
    ArcadeContent(type: GameType.animalQuiz, title: 'اختبار الحيوانات', instruction: 'اختر الإجابة الصحيحة', mode: ArcadeMode.quiz, prompts: ['ما أسرع حيوان بري؟','ما أكبر حيوان معروف على الأرض؟'], options: ['الفهد','الحوت الأزرق','الأسد','الفيل'], correctAnswers: [0,0], choicesByPrompt: [['الفهد','الأسد','الحصان','الذئب'],['الحوت الأزرق','الفيل','الزرافة','الحوت']]),
    ArcadeContent(type: GameType.foodQuiz, title: 'اختبار الطعام', instruction: 'اختر الإجابة الصحيحة عن الطعام', mode: ArcadeMode.quiz, prompts: ['أي طبق ياباني يُحضّر غالبًا بالأرز والسمك؟','أي طبق أرز متبل مشهور في اليمن والخليج؟','أي طعام إيطالي دائري غالبًا تعلوه الجبنة؟','أي مكوّن يُهرس لتحضير الحمص بالطحينة؟'], correctAnswers: [0,1,0,0], choicesByPrompt: [['سوشي','كبسة','بيتزا','باستا'],['باستا','كبسة','سوشي','بيتزا'],['بيتزا','سوشي','كبسة','باستا'],['الحمص','الأرز','البطاطس','التفاح']]),
    ArcadeContent(type: GameType.geographyQuiz, title: 'اختبار الجغرافيا', instruction: 'أجب عن أسئلة الجغرافيا', mode: ArcadeMode.quiz, prompts: ['ما أعلى جبل فوق مستوى سطح البحر؟','ما أكبر قارات العالم مساحةً؟'], options: ['إيفرست','آسيا','الألب','أفريقيا'], correctAnswers: [0,0], choicesByPrompt: [['إيفرست','كي 2','الألب','دنالي'],['آسيا','أفريقيا','أوروبا','أمريكا']]),
    ArcadeContent(type: GameType.scienceQuiz, title: 'اختبار العلوم', instruction: 'أجب عن أسئلة العلوم', mode: ArcadeMode.quiz, prompts: ['ما الصيغة الكيميائية للماء؟','ما الجسيم ذو الشحنة السالبة الموجود حول نواة الذرة؟'], options: ['H₂O','إلكترون','CO₂','بروتون'], correctAnswers: [0,0], choicesByPrompt: [['H₂O','CO₂','O₂','NaCl'],['إلكترون','بروتون','نيوترون','فوتون']]),
    ArcadeContent(type: GameType.historyQuiz, title: 'اختبار التاريخ', instruction: 'أجب عن أسئلة التاريخ', mode: ArcadeMode.quiz, prompts: ['في أي بلد ازدهرت حضارة سبأ القديمة؟','في أي بلد تقع أهرامات الجيزة؟'], options: ['اليمن','مصر','روما','الهند'], correctAnswers: [0,0], choicesByPrompt: [['اليمن','مصر','العراق','اليونان'],['مصر','اليمن','السودان','ليبيا']]),
    ArcadeContent(type: GameType.languageQuiz, title: 'اختبار اللغة العربية', instruction: 'اختر الإجابة اللغوية الصحيحة', mode: ArcadeMode.quiz, prompts: ['ما جمع كلمة «كتاب»؟','ما ضد كلمة «كبير»؟'], options: ['كتب','صغير','كتابان','طويل'], correctAnswers: [0,0], choicesByPrompt: [['كتب','كتابان','كتابات','كاتبون'],['صغير','طويل','قصير','بعيد']]),
    ArcadeContent(type: GameType.riddleRush, title: 'سباق الألغاز', instruction: 'حل اللغز قبل انتهاء الوقت', mode: ArcadeMode.quiz, prompts: ['له أسنان ولا يعض، ما هو؟','يمضي دائمًا ولا يعود، ما هو؟'], options: ['المشط','الوقت','الأسد','الكرسي'], correctAnswers: [0,1], choicesByPrompt: [['المشط','الكتاب','الباب','القلم'],['الوقت','الطريق','الظل','النهر']]),
    ArcadeContent(type: GameType.anagramBattle, title: 'تحدي ترتيب الحروف', instruction: 'شاهد الحروف المبعثرة واختر الكلمة الصحيحة', mode: ArcadeMode.word, prompts: ['مدرسة','كتاب','هاتف']),
    ArcadeContent(type: GameType.mathDuel, title: 'Math Duel', instruction: 'احسب قبل خصمك', mode: ArcadeMode.math),
    ArcadeContent(type: GameType.codeBreaker, title: 'Code Breaker', instruction: 'اكتشف الشفرة الرقمية', mode: ArcadeMode.code),
    ArcadeContent(type: GameType.lightSwitch, title: 'Light Switch', instruction: 'أطفئ كل الأضواء بأقل عدد من النقلات', mode: ArcadeMode.lights),
    ArcadeContent(type: GameType.connectPairs, title: 'Connect Pairs', instruction: 'صل كل زوج متشابه', mode: ArcadeMode.pairs),
    ArcadeContent(type: GameType.wordGuess, title: 'Word Guess', instruction: 'خمن الكلمة حرفًا حرفًا', mode: ArcadeMode.word, prompts: ['قمر','كتاب','مفتاح','حديقة']),
    ArcadeContent(type: GameType.picturePuzzle, title: 'Picture Puzzle', instruction: 'رتب القطع لتكوين الصورة', mode: ArcadeMode.pairs),
    ArcadeContent(type: GameType.balanceBeam, title: 'Balance Beam', instruction: 'حافظ على المؤشر في المنتصف', mode: ArcadeMode.timing),
    ArcadeContent(type: GameType.rocketRace, title: 'Rocket Race', instruction: 'اضغط لدفع الصاروخ للأمام', mode: ArcadeMode.race),
    ArcadeContent(type: GameType.galaxyCatch, title: 'Galaxy Catch', instruction: 'اجمع النجوم وتجنب النيازك', mode: ArcadeMode.explorer),
    ArcadeContent(type: GameType.rhythmTap, title: 'Rhythm Tap', instruction: 'اضغط مع النبض', mode: ArcadeMode.timing),
  ];

  static final Map<GameType, ArcadeContent> byType = {
    for (final item in all) item.type: item,
  };

  static ArcadeContent forType(GameType type) =>
      byType[type] ?? ArcadeContent(type: type, title: type.name, instruction: 'ابدأ اللعب', mode: ArcadeMode.target);
}
