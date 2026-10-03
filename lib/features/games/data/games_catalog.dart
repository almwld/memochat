import '../models/game.dart';

class GamesCatalog {
  static const all = <GameDefinition>[
    GameDefinition(type:GameType.xo,title:'إكس أو',subtitle:'تحدي 3×3',icon:'✕○',minPlayers:2,maxPlayers:2),
    GameDefinition(type:GameType.quizBattle,title:'Quiz Battle',subtitle:'أسئلة سريعة',icon:'?',minPlayers:2,maxPlayers:8),
    GameDefinition(type:GameType.emojiReaction,title:'Emoji Reaction',subtitle:'رد الفعل الأسرع',icon:'☺',minPlayers:2,maxPlayers:8),
    GameDefinition(type:GameType.diceRoll,title:'Dice Roll',subtitle:'ارمِ النرد',icon:'⚄',minPlayers:2,maxPlayers:8),
    GameDefinition(type:GameType.drawGuess,title:'Draw & Guess',subtitle:'ارسم وخمّن',icon:'✎',minPlayers:2,maxPlayers:6),
    GameDefinition(type:GameType.wordChain,title:'Word Chain',subtitle:'سلسلة الكلمات',icon:'Aa',minPlayers:2,maxPlayers:6),
    GameDefinition(type:GameType.truthDare,title:'Truth or Dare',subtitle:'صراحة أم تحدي',icon:'!',minPlayers:2,maxPlayers:8),
    GameDefinition(type:GameType.guessSong,title:'Guess the Song',subtitle:'خمن الأغنية',icon:'♫',minPlayers:2,maxPlayers:8),
    GameDefinition(type:GameType.memoryMatch,title:'Memory Match',subtitle:'اختبر ذاكرتك',icon:'▦',minPlayers:2,maxPlayers:2),
    GameDefinition(type:GameType.trivia,title:'Trivia Challenge',subtitle:'تحدي المعلومات',icon:'★',minPlayers:2,maxPlayers:8),
    GameDefinition(type:GameType.quickTap,title:'Quick Tap',subtitle:'اضغط أولاً',icon:'↯',minPlayers:2,maxPlayers:4),
    GameDefinition(type:GameType.wouldYouRather,title:'Would You Rather',subtitle:'ماذا تفضل؟',icon:'↔',minPlayers:2,maxPlayers:8),
    GameDefinition(type:GameType.speedMath,title:'Speed Math',subtitle:'حساب سريع',icon:'∑',minPlayers:2,maxPlayers:4),
    GameDefinition(type:GameType.movieQuiz,title:'Movie Quiz',subtitle:'اختبار الأفلام',icon:'▶',minPlayers:2,maxPlayers:8),
    GameDefinition(type:GameType.sudokuDuel,title:'Sudoku Duel',subtitle:'سودوكو ثنائي',icon:'⊞',minPlayers:2,maxPlayers:2),
  ];
}
