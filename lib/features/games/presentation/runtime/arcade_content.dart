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
    ArcadeContent(type: GameType.quizBattle, title: 'تحدي المعلومات', instruction: 'اقرأ السؤال واختر الإجابة الصحيحة', mode: ArcadeMode.quiz, prompts: ['ما الكوكب المعروف بلونه الأحمر؟','ما عاصمة اليمن؟','كم ضلعًا للمثلث؟','ما أكبر محيط في العالم؟','ما الصيغة الكيميائية للماء؟','كم يومًا في الأسبوع؟','ما أكبر قارات العالم مساحةً؟','ما جمع كلمة كتاب؟'], options: ['المريخ','صنعاء','3','المحيط الهادئ','H₂O','7','آسيا','كتب'], correctAnswers: [0,0,0,0,0,0,0,0], choicesByPrompt: [['المريخ','الزهرة','الأرض','المشتري'],['صنعاء','عدن','تعز','الحديدة'],['3','4','5','6'],['المحيط الهادئ','المحيط الأطلسي','المحيط الهندي','المحيط المتجمد'],['H₂O','CO₂','O₂','NaCl'],['7','5','6','8'],['آسيا','أفريقيا','أوروبا','أمريكا الجنوبية'],['كتب','كتابان','كاتب','مكتبة']]),
    ArcadeContent(type: GameType.emojiReaction, title: 'Emoji Reaction', instruction: 'اضغط الرمز المطلوب بأسرع وقت', mode: ArcadeMode.choice, options: ['❤','★','●','◆']),
    ArcadeContent(type: GameType.diceRoll, title: 'Dice Roll', instruction: 'ارمِ النرد واجمع أعلى مجموع', mode: ArcadeMode.timing),
    ArcadeContent(type: GameType.drawGuess, title: 'Draw & Guess', instruction: 'اختر كلمة وارسمها ليخمنها خصمك', mode: ArcadeMode.choice, options: ['بيت','شمس','قمر','سيارة']),
    ArcadeContent(type: GameType.wordChain, title: 'Word Chain', instruction: 'كوّن كلمة تبدأ بآخر حرف', mode: ArcadeMode.word, prompts: ['كتاب','باب','بحر','ربيع']),
    ArcadeContent(type: GameType.truthDare, title: 'Truth or Dare', instruction: 'اختر صراحة أو تحديًا', mode: ArcadeMode.choice, options: ['صراحة','تحدي']),
    ArcadeContent(type: GameType.guessSong, title: 'تعرّف على النمط الموسيقي', instruction: 'اقرأ وصف النمط واختر اسمه', mode: ArcadeMode.quiz, prompts: ['أي نمط يعتمد غالبًا على الارتجال والآلات النحاسية والإيقاعات المتنوعة؟','أي نمط يرتبط غالبًا بالغيتار الكهربائي والإيقاع القوي؟','أي نمط يرتبط بالأوركسترا والسيمفونيات؟'], options: ['جاز','روك','موسيقى كلاسيكية'], correctAnswers: [0,0,0], choicesByPrompt: [['جاز','روك','موسيقى كلاسيكية','موسيقى إلكترونية'],['روك','جاز','موسيقى كلاسيكية','إنشاد'],['موسيقى كلاسيكية','روك','جاز','هيب هوب']]),
    ArcadeContent(type: GameType.memoryMatch, title: 'Memory Match', instruction: 'اعثر على الأزواج المتطابقة', mode: ArcadeMode.memory),
    ArcadeContent(type: GameType.trivia, title: 'تحدي المعلومات العامة', instruction: 'اقرأ السؤال ثم اختر الإجابة الصحيحة', mode: ArcadeMode.quiz, prompts: ['ما أكبر محيط في العالم؟','ما اللغة الأساسية للقرآن الكريم؟','كم ضلعًا للشكل السداسي؟','أيّ هذه الحيوانات من الثدييات؟','ما عاصمة مصر؟','ما أقرب نجم إلى الأرض؟'], options: ['المحيط الهادئ','العربية','6','الدلفين','القاهرة','الشمس'], correctAnswers: [0,0,0,0,0,0], choicesByPrompt: [['المحيط الهادئ','المحيط الأطلسي','المحيط الهندي','المحيط المتجمد'],['العربية','الإنجليزية','الفرنسية','الإسبانية'],['6','4','5','8'],['الدلفين','التمساح','السلحفاة','الضفدع'],['القاهرة','الإسكندرية','الأقصر','أسوان'],['الشمس','الشعرى اليمانية','سيريوس','النجم القطبي']]),
    ArcadeContent(type: GameType.quickTap, title: 'Quick Tap', instruction: 'اضغط الأهداف بسرعة', mode: ArcadeMode.target),
    ArcadeContent(type: GameType.wouldYouRather, title: 'Would You Rather', instruction: 'اختر أحد الخيارين', mode: ArcadeMode.choice, options: ['السفر للماضي','السفر للمستقبل']),
    ArcadeContent(type: GameType.speedMath, title: 'Speed Math', instruction: 'حل المسألة بسرعة', mode: ArcadeMode.math),
    ArcadeContent(type: GameType.movieQuiz, title: 'اختبار أنواع الأفلام', instruction: 'اقرأ الوصف واختر النوع الذي يناسبه', mode: ArcadeMode.quiz, prompts: ['أي نوع يركز عادةً على المطاردات والمواجهات؟','أي نوع يهدف أساسًا إلى إضحاك المشاهد؟','أي نوع يستخدم غالبًا الفضاء والتقنيات المستقبلية؟'], options: ['أكشن','كوميديا','خيال علمي'], correctAnswers: [0,0,0], choicesByPrompt: [['أكشن','وثائقي','رومانسي','موسيقي'],['كوميديا','رعب','حربي','غموض'],['خيال علمي','دراما تاريخية','كوميديا','سيرة ذاتية']]),
    ArcadeContent(type: GameType.sudokuDuel, title: 'Sudoku Duel', instruction: 'أكمل شبكة 4×4', mode: ArcadeMode.pairs),
    ArcadeContent(type: GameType.colorRush, title: 'Color Rush', instruction: 'اضغط اللون المطلوب', mode: ArcadeMode.color),
    ArcadeContent(type: GameType.higherLower, title: 'Higher or Lower', instruction: 'هل الرقم التالي أعلى أم أقل؟', mode: ArcadeMode.choice, options: ['أعلى','أقل','متساوٍ']),
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
    ArcadeContent(type: GameType.fastChoice, title: 'اختيار سريع', instruction: 'أجب عن السؤال قبل انتهاء الوقت', mode: ArcadeMode.quiz, prompts: ['كم يساوي 2 + 3؟','كم ضلعًا للمربع؟','ما عاصمة اليمن؟','ما الكوكب الأحمر؟'], options: ['5','4','صنعاء','المريخ'], correctAnswers: [0,0,0,0], choicesByPrompt: [['5','4','6','7'],['3','4','5','6'],['صنعاء','عدن','تعز','إب'],['المريخ','الزهرة','الأرض','زحل']]),
    ArcadeContent(type: GameType.trueFalse, title: 'True or False', instruction: 'احكم على العبارة', mode: ArcadeMode.quiz, prompts: ['الماء يغلي عند 100°م.','الشمس كوكب.','اليمن في آسيا.'], options: ['صحيح','خطأ'], correctAnswers: [0,1,0], choicesByPrompt: [['صحيح','خطأ'],['صحيح','خطأ'],['صحيح','خطأ']]),
    ArcadeContent(type: GameType.flagQuiz, title: 'Flag Quiz', instruction: 'اختر الدولة التي ينتمي إليها العلم', mode: ArcadeMode.quiz, prompts: ['🇾🇪','🇯🇵','🇫🇷'], options: ['اليمن','اليابان','فرنسا'], correctAnswers: [0,1,2], choicesByPrompt: [['اليمن','اليابان','فرنسا','مصر'],['اليابان','الصين','كوريا','تايلاند'],['فرنسا','إيطاليا','بلجيكا','هولندا']]),
    ArcadeContent(type: GameType.animalQuiz, title: 'Animal Quiz', instruction: 'اختر الحيوان الصحيح', mode: ArcadeMode.quiz, prompts: ['أسرع حيوان بري؟','أكبر حيوان؟'], options: ['الفهد','الحوت الأزرق','الأسد','الفيل'], correctAnswers: [0,1], choicesByPrompt: [['الفهد','الأسد','الحصان','الذئب'],['الحوت الأزرق','الفيل','الزرافة','الحوت']]),
    ArcadeContent(type: GameType.foodQuiz, title: 'اختبار الطعام', instruction: 'اقرأ الوصف واختر الطعام الصحيح', mode: ArcadeMode.quiz, prompts: ['أي طبق يُحضّر غالبًا من الأرز واللحم أو الدجاج والبهارات؟','أي طعام إيطالي دائري يُخبز غالبًا مع الجبن؟','ما المكوّن الأساسي في السوشي التقليدي؟'], options: ['الكبسة','البيتزا','الأرز'], correctAnswers: [0,0,0], choicesByPrompt: [['الكبسة','السوشي','البيتزا','الباستا'],['البيتزا','الفلافل','السوشي','الشوربة'],['الأرز','الخبز','البطاطس','الذرة']]),
    ArcadeContent(type: GameType.geographyQuiz, title: 'Geography Quiz', instruction: 'أجب عن الجغرافيا', mode: ArcadeMode.quiz, prompts: ['أعلى جبل؟','أكبر قارة؟'], options: ['إيفرست','آسيا','الألب','أفريقيا'], correctAnswers: [0,1], choicesByPrompt: [['إيفرست','كي 2','الألب','دنالي'],['آسيا','أفريقيا','أوروبا','أمريكا']]),
    ArcadeContent(type: GameType.scienceQuiz, title: 'Science Quiz', instruction: 'أجب عن العلوم', mode: ArcadeMode.quiz, prompts: ['رمز الماء؟','ما الذي يدور حول النواة؟'], options: ['H₂O','إلكترون','CO₂','بروتون'], correctAnswers: [0,1], choicesByPrompt: [['H₂O','CO₂','O₂','NaCl'],['إلكترون','بروتون','نيوترون','فوتون']]),
    ArcadeContent(type: GameType.historyQuiz, title: 'History Quiz', instruction: 'أجب عن التاريخ', mode: ArcadeMode.quiz, prompts: ['أين قامت حضارة سبأ؟','أين بُنيت الأهرامات؟'], options: ['اليمن','مصر','روما','الهند'], correctAnswers: [0,1], choicesByPrompt: [['اليمن','مصر','العراق','اليونان'],['مصر','اليمن','السودان','ليبيا']]),
    ArcadeContent(type: GameType.languageQuiz, title: 'Language Quiz', instruction: 'اختر الصياغة الصحيحة', mode: ArcadeMode.quiz, prompts: ['جمع كتاب؟','ضد كلمة كبير؟'], options: ['كتب','صغير','كتابان','طويل'], correctAnswers: [0,1], choicesByPrompt: [['كتب','كتابان','كتابات','كاتبون'],['صغير','طويل','قصير','بعيد']]),
    ArcadeContent(type: GameType.riddleRush, title: 'ألغاز سريعة', instruction: 'اقرأ اللغز واختر الحل الأنسب', mode: ArcadeMode.quiz, prompts: ['له أسنان ولا يعضّ، فما هو؟','يسمع بلا أذن ويتكلم بلا لسان، فما هو؟','كلما أخذتَ منه كبر، فما هو؟'], options: ['المشط','الصدى','الحفرة'], correctAnswers: [0,0,0], choicesByPrompt: [['المشط','الأسد','الكرسي','القلم'],['الصدى','الظل','المفتاح','الوقت'],['الحفرة','الكتاب','البحر','الضوء']]),
    ArcadeContent(type: GameType.anagramBattle, title: 'Anagram Battle', instruction: 'رتب الحروف بسرعة', mode: ArcadeMode.word, prompts: ['ةسردم','باتك','فتاه']),
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
