import 'package:flutter/material.dart';

class GameDefinition {
  const GameDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.icon,
    required this.color,
    this.featured = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final String category;
  final IconData icon;
  final Color color;
  final bool featured;
}

const gameCatalog = <GameDefinition>[
  GameDefinition(id:'memory_match',title:'لعبة الذاكرة',subtitle:'طابق البطاقات بأقل عدد من المحاولات.',category:'أساسية',icon:Icons.grid_view_rounded,color:Color(0xFF0A8F83),featured:true),
  GameDefinition(id:'speed_test',title:'اختبار السرعة',subtitle:'اختبر سرعة استجابتك للهدف.',category:'أساسية',icon:Icons.speed_rounded,color:Color(0xFFE56B2F),featured:true),
  GameDefinition(id:'word_builder',title:'بناء الكلمات',subtitle:'كوّن كلمات من الحروف المتاحة.',category:'كلمات',icon:Icons.abc_rounded,color:Color(0xFF6C4AD4)),
  GameDefinition(id:'number_puzzle',title:'لغز الأرقام',subtitle:'رتّب الأرقام للوصول إلى الحل.',category:'منطق',icon:Icons.pin_rounded,color:Color(0xFF1776C4)),
  GameDefinition(id:'pattern',title:'النمط المتتابع',subtitle:'تذكّر النمط وأعد رسمه.',category:'ذاكرة',icon:Icons.auto_awesome_rounded,color:Color(0xFFD64E8A)),
  GameDefinition(id:'color_match',title:'مطابقة الألوان',subtitle:'اختر اللون الصحيح قبل انتهاء الوقت.',category:'سرعة',icon:Icons.palette_rounded,color:Color(0xFF0B9A75)),
  GameDefinition(id:'shape_match',title:'مطابقة الأشكال',subtitle:'ميّز الشكل المختلف بسرعة.',category:'تركيز',icon:Icons.category_rounded,color:Color(0xFF7C57D1)),
  GameDefinition(id:'sequence',title:'التسلسل',subtitle:'أكمل التسلسل المنطقي.',category:'منطق',icon:Icons.linear_scale_rounded,color:Color(0xFFCE6D22)),
  GameDefinition(id:'guess',title:'التخمين',subtitle:'اقترب من الرقم السري في أقل محاولات.',category:'منطق',icon:Icons.help_outline_rounded,color:Color(0xFF1987A6)),
  GameDefinition(id:'math',title:'تحدي الرياضيات',subtitle:'حل أكبر عدد من المسائل.',category:'تعليم',icon:Icons.calculate_rounded,color:Color(0xFF3D76C5)),
  GameDefinition(id:'trivia',title:'معلومات عامة',subtitle:'أسئلة قصيرة في المعرفة والثقافة.',category:'معرفة',icon:Icons.lightbulb_outline_rounded,color:Color(0xFFB56B19)),
  GameDefinition(id:'puzzle',title:'الألغاز',subtitle:'حل التحديات الصغيرة خطوة بخطوة.',category:'منطق',icon:Icons.extension_rounded,color:Color(0xFF8A50B5)),
  GameDefinition(id:'drawing',title:'الرسم السريع',subtitle:'ارسم وشارك إبداعك مع أصدقائك.',category:'إبداع',icon:Icons.brush_rounded,color:Color(0xFFDD567B)),
  GameDefinition(id:'music',title:'إيقاع الموسيقى',subtitle:'اضغط مع النبض وحافظ على السلسلة.',category:'إيقاع',icon:Icons.graphic_eq_rounded,color:Color(0xFF0F8A9A)),
  GameDefinition(id:'logic',title:'التفكير المنطقي',subtitle:'قرارات ذكية في وقت محدود.',category:'منطق',icon:Icons.psychology_alt_rounded,color:Color(0xFF5866B8)),
  GameDefinition(id:'color_rush',title:'Color Rush',subtitle:'التقط اللون المطابق بسرعة متزايدة.',category:'سرعة',icon:Icons.blur_on_rounded,color:Color(0xFFEA572F),featured:true),
  GameDefinition(id:'higher_lower',title:'أعلى أم أقل؟',subtitle:'توقع البطاقة التالية.',category:'بطاقات',icon:Icons.unfold_more_rounded,color:Color(0xFF117A8B)),
  GameDefinition(id:'number_guess',title:'خمن الرقم',subtitle:'استعمل التلميحات للوصول للرقم.',category:'منطق',icon:Icons.numbers_rounded,color:Color(0xFF4476C4)),
  GameDefinition(id:'word_scramble',title:'كلمات مبعثرة',subtitle:'أعد ترتيب الحروف قبل نفاد الوقت.',category:'كلمات',icon:Icons.shuffle_rounded,color:Color(0xFF9756B5)),
  GameDefinition(id:'pattern_tap',title:'Pattern Tap',subtitle:'اضغط البلاطات بالترتيب الصحيح.',category:'ذاكرة',icon:Icons.apps_rounded,color:Color(0xFFCC6A2E)),
  GameDefinition(id:'odd_one_out',title:'العنصر المختلف',subtitle:'اعثر على المختلف بين العناصر.',category:'تركيز',icon:Icons.filter_vintage_rounded,color:Color(0xFF197D8F)),
  GameDefinition(id:'four_in_row',title:'أربعة على التوالي',subtitle:'خطط لتكوين سلسلة من أربع.',category:'استراتيجية',icon:Icons.view_module_rounded,color:Color(0xFF4C65B7)),
  GameDefinition(id:'dots_boxes',title:'نقاط ومربعات',subtitle:'أغلق أكبر عدد من المربعات.',category:'استراتيجية',icon:Icons.grid_3x3_rounded,color:Color(0xFFAF5B82)),
  GameDefinition(id:'reaction_race',title:'سباق رد الفعل',subtitle:'استجب للإشارة في اللحظة الصحيحة.',category:'سرعة',icon:Icons.flash_on_rounded,color:Color(0xFFE17925)),
  GameDefinition(id:'card_flip',title:'قلب البطاقات',subtitle:'تذكّر أماكن البطاقات المتشابهة.',category:'ذاكرة',icon:Icons.style_rounded,color:Color(0xFF4E75C4)),
  GameDefinition(id:'treasure_hunt',title:'البحث عن الكنز',subtitle:'اختر المسار الصحيح إلى الكنز.',category:'مغامرة',icon:Icons.explore_rounded,color:Color(0xFFC27125)),
  GameDefinition(id:'maze_runner',title:'متاهة',subtitle:'اعثر على الطريق في أقل وقت.',category:'منطق',icon:Icons.route_rounded,color:Color(0xFF278B79)),
  GameDefinition(id:'stack_tower',title:'برج المكعبات',subtitle:'وازن الطبقات وابنِ أعلى برج.',category:'مهارة',icon:Icons.layers_rounded,color:Color(0xFF6A5ACD)),
  GameDefinition(id:'target_hit',title:'إصابة الهدف',subtitle:'اضرب الأهداف المتحركة بدقة.',category:'سرعة',icon:Icons.gps_fixed_rounded,color:Color(0xFFD6534C)),
  GameDefinition(id:'bubble_pop',title:'فرقعة الفقاعات',subtitle:'فرّقع الفقاعات قبل اختفائها.',category:'سرعة',icon:Icons.bubble_chart_rounded,color:Color(0xFF168BA4)),
  GameDefinition(id:'color_match_2',title:'كرة اللون',subtitle:'طابق الكرة مع الهدف.',category:'سرعة',icon:Icons.circle_rounded,color:Color(0xFF1D9A78)),
  GameDefinition(id:'shape_match_2',title:'أشكال متحركة',subtitle:'التقط الشكل المطلوب فقط.',category:'تركيز',icon:Icons.interests_rounded,color:Color(0xFF8459C9)),
  GameDefinition(id:'sequence_recall',title:'استدعاء التسلسل',subtitle:'احفظ الترتيب ثم أعده.',category:'ذاكرة',icon:Icons.replay_rounded,color:Color(0xFFBC6B2A)),
  GameDefinition(id:'fast_choice',title:'اختيار سريع',subtitle:'اتخذ القرار قبل تبدّل الخيارات.',category:'سرعة',icon:Icons.touch_app_rounded,color:Color(0xFF0B8990)),
  GameDefinition(id:'true_false',title:'صح أم خطأ',subtitle:'اختبر معلوماتك بسرعة.',category:'معرفة',icon:Icons.fact_check_outlined,color:Color(0xFF4178BD)),
  GameDefinition(id:'flag_quiz',title:'أعلام العالم',subtitle:'تعرّف إلى العلم الصحيح.',category:'معرفة',icon:Icons.flag_outlined,color:Color(0xFFB65769)),
  GameDefinition(id:'animal_quiz',title:'عالم الحيوانات',subtitle:'أسئلة بصرية عن الحيوانات.',category:'معرفة',icon:Icons.pets_rounded,color:Color(0xFFB57628)),
  GameDefinition(id:'food_quiz',title:'مذاقات العالم',subtitle:'تعرّف إلى الأطباق الشهيرة.',category:'معرفة',icon:Icons.restaurant_rounded,color:Color(0xFFD45E3D)),
  GameDefinition(id:'geography',title:'جغرافيا سريعة',subtitle:'أماكن وحدود ومعالم.',category:'معرفة',icon:Icons.public_rounded,color:Color(0xFF2586A1)),
  GameDefinition(id:'science',title:'مختبر العلوم',subtitle:'أسئلة وتجارب علمية قصيرة.',category:'تعليم',icon:Icons.science_rounded,color:Color(0xFF5677C6)),
  GameDefinition(id:'history',title:'خط الزمن',subtitle:'رتّب الأحداث التاريخية.',category:'معرفة',icon:Icons.timeline_rounded,color:Color(0xFF9B6234)),
  GameDefinition(id:'language',title:'مختبر اللغة',subtitle:'حروف وكلمات وتراكيب.',category:'كلمات',icon:Icons.translate_rounded,color:Color(0xFF4D74B6)),
  GameDefinition(id:'riddle_rush',title:'سباق الألغاز',subtitle:'حل اللغز قبل خصم النقاط.',category:'منطق',icon:Icons.quiz_outlined,color:Color(0xFF8759B9)),
  GameDefinition(id:'anagram_battle',title:'معركة الكلمات',subtitle:'كوّن الكلمة الأسرع.',category:'كلمات',icon:Icons.spellcheck_rounded,color:Color(0xFFB9577A)),
  GameDefinition(id:'math_duel',title:'مبارزة الرياضيات',subtitle:'تحدٍّ سريع للمهارة الحسابية.',category:'تعليم',icon:Icons.functions_rounded,color:Color(0xFF357DBB)),
  GameDefinition(id:'code_breaker',title:'كاسر الشفرة',subtitle:'حل الرمز السري بالمحاولات.',category:'منطق',icon:Icons.lock_open_rounded,color:Color(0xFF4C6EBC)),
  GameDefinition(id:'light_switch',title:'مفاتيح الضوء',subtitle:'أطفئ كل الأضواء بأقل نقلات.',category:'منطق',icon:Icons.lightbulb_rounded,color:Color(0xFFD18A22)),
  GameDefinition(id:'connect_pairs',title:'وصل الأزواج',subtitle:'وصل النقاط دون تقاطع.',category:'منطق',icon:Icons.share_rounded,color:Color(0xFF1B8C84)),
  GameDefinition(id:'word_guess',title:'خمن الكلمة',subtitle:'اكتشف الكلمة حرفًا بعد حرف.',category:'كلمات',icon:Icons.text_fields_rounded,color:Color(0xFF6A66B9)),
  GameDefinition(id:'picture_puzzle',title:'لغز الصورة',subtitle:'كوّن الصورة من القطع.',category:'ألغاز',icon:Icons.image_search_rounded,color:Color(0xFFB15B7C)),
  GameDefinition(id:'balance_beam',title:'ميزان التوازن',subtitle:'حافظ على التوازن لأطول وقت.',category:'مهارة',icon:Icons.balance_rounded,color:Color(0xFF2D8B88)),
  GameDefinition(id:'rocket_race',title:'سباق الصواريخ',subtitle:'تجنب العوائق واجمع الطاقة.',category:'مغامرة',icon:Icons.rocket_launch_rounded,color:Color(0xFFE06436)),
  GameDefinition(id:'galaxy_catch',title:'صائد المجرة',subtitle:'اجمع النجوم وتجنب الشهب.',category:'مغامرة',icon:Icons.auto_awesome_rounded,color:Color(0xFF4F5FC1)),
  GameDefinition(id:'rhythm_tap',title:'إيقاع Tap',subtitle:'اضغط مع الإيقاع وحافظ على السلسلة.',category:'إيقاع',icon:Icons.music_note_rounded,color:Color(0xFFB95391)),
];
