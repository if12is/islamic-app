/// One of the names, with what it means in plain Arabic.
class DivineName {
  const DivineName({
    required this.number,
    required this.arabic,
    required this.transliteration,
    required this.meaningAr,
  });

  /// 1-99, in the order of the narration.
  final int number;

  final String arabic;

  /// For anyone reading in English who still wants to say it.
  final String transliteration;

  /// A short gloss, not a tafsir: enough to know what is being said.
  final String meaningAr;
}

/// The ninety-nine names, as listed in the narration of at-Tirmidhi.
///
/// A note on why this list and not another: the hadith «إن لله تسعة وتسعين اسمًا»
/// is agreed upon, but the enumeration of the names is not part of it — it is a
/// listing appended by a narrator, and other listings differ. So this is the
/// most widely circulated one rather than the only correct one, and the screen
/// says as much instead of presenting it as revelation.
class DivineNames {
  DivineNames._();

  /// What the count rests on, quoted where the list is shown.
  static const String hadithAr =
      'إِنَّ لِلَّهِ تِسْعَةً وَتِسْعِينَ اسْمًا، مِائَةً إِلَّا وَاحِدًا، '
      'مَنْ أَحْصَاهَا دَخَلَ الْجَنَّةَ.';

  static const String hadithSourceAr = 'متفق عليه — البخاري ومسلم';

  /// Why the list itself carries less weight than the count.
  static const String listingNoteAr =
      'عدد الأسماء ثابت في الحديث المتفق عليه، أمّا سرد الأسماء نفسه فمن رواية '
      'الترمذي، وقد اختلفت روايات السرد. فهذه أشهر القوائم لا القائمة الوحيدة.';

  static const List<DivineName> all = [
    DivineName(
      number: 1,
      arabic: 'الرَّحْمَنُ',
      transliteration: 'Ar-Rahman',
      meaningAr: 'الواسع الرحمة لجميع الخلق في الدنيا.',
    ),
    DivineName(
      number: 2,
      arabic: 'الرَّحِيمُ',
      transliteration: 'Ar-Raheem',
      meaningAr: 'الموصل رحمته لمن شاء من عباده.',
    ),
    DivineName(
      number: 3,
      arabic: 'الْمَلِكُ',
      transliteration: 'Al-Malik',
      meaningAr: 'المالك المتصرف في ملكه بلا منازع.',
    ),
    DivineName(
      number: 4,
      arabic: 'الْقُدُّوسُ',
      transliteration: 'Al-Quddus',
      meaningAr: 'المنزَّه عن كل نقص وعيب.',
    ),
    DivineName(
      number: 5,
      arabic: 'السَّلَامُ',
      transliteration: 'As-Salam',
      meaningAr: 'السالم من كل آفة، ومنه السلامة لخلقه.',
    ),
    DivineName(
      number: 6,
      arabic: 'الْمُؤْمِنُ',
      transliteration: 'Al-Mu\'min',
      meaningAr: 'المصدِّق رسله، والمؤمِّن عباده من عذابه.',
    ),
    DivineName(
      number: 7,
      arabic: 'الْمُهَيْمِنُ',
      transliteration: 'Al-Muhaymin',
      meaningAr: 'الرقيب على خلقه، الشاهد على أعمالهم.',
    ),
    DivineName(
      number: 8,
      arabic: 'الْعَزِيزُ',
      transliteration: 'Al-Azeez',
      meaningAr: 'الغالب الذي لا يُغلَب.',
    ),
    DivineName(
      number: 9,
      arabic: 'الْجَبَّارُ',
      transliteration: 'Al-Jabbar',
      meaningAr: 'الذي يجبر الكسير ويقهر كل شيء.',
    ),
    DivineName(
      number: 10,
      arabic: 'الْمُتَكَبِّرُ',
      transliteration: 'Al-Mutakabbir',
      meaningAr: 'المتعالي عن صفات الخلق، الكبرياء رداؤه.',
    ),
    DivineName(
      number: 11,
      arabic: 'الْخَالِقُ',
      transliteration: 'Al-Khaliq',
      meaningAr: 'الموجِد للأشياء من العدم على غير مثال.',
    ),
    DivineName(
      number: 12,
      arabic: 'الْبَارِئُ',
      transliteration: 'Al-Bari\'',
      meaningAr: 'المنشئ للخلق بريئًا من التفاوت.',
    ),
    DivineName(
      number: 13,
      arabic: 'الْمُصَوِّرُ',
      transliteration: 'Al-Musawwir',
      meaningAr: 'الذي صوَّر كل شيء بالصورة التي أرادها.',
    ),
    DivineName(
      number: 14,
      arabic: 'الْغَفَّارُ',
      transliteration: 'Al-Ghaffar',
      meaningAr: 'كثير المغفرة، يستر الذنب ويعفو عنه.',
    ),
    DivineName(
      number: 15,
      arabic: 'الْقَهَّارُ',
      transliteration: 'Al-Qahhar',
      meaningAr: 'الذي قهر كل شيء ودانت له الخلائق.',
    ),
    DivineName(
      number: 16,
      arabic: 'الْوَهَّابُ',
      transliteration: 'Al-Wahhab',
      meaningAr: 'كثير العطاء بلا عوض ولا مقابل.',
    ),
    DivineName(
      number: 17,
      arabic: 'الرَّزَّاقُ',
      transliteration: 'Ar-Razzaq',
      meaningAr: 'المتكفل بأرزاق خلقه أجمعين.',
    ),
    DivineName(
      number: 18,
      arabic: 'الْفَتَّاحُ',
      transliteration: 'Al-Fattah',
      meaningAr: 'الحاكم بين عباده، الفاتح لهم أبواب الرحمة.',
    ),
    DivineName(
      number: 19,
      arabic: 'الْعَلِيمُ',
      transliteration: 'Al-Aleem',
      meaningAr: 'المحيط علمه بكل شيء، ظاهره وباطنه.',
    ),
    DivineName(
      number: 20,
      arabic: 'الْقَابِضُ',
      transliteration: 'Al-Qabid',
      meaningAr: 'الذي يقبض الرزق والأرواح بحكمته.',
    ),
    DivineName(
      number: 21,
      arabic: 'الْبَاسِطُ',
      transliteration: 'Al-Basit',
      meaningAr: 'الذي يبسط الرزق ويوسّعه على من يشاء.',
    ),
    DivineName(
      number: 22,
      arabic: 'الْخَافِضُ',
      transliteration: 'Al-Khafid',
      meaningAr: 'الذي يخفض المتكبرين والظالمين.',
    ),
    DivineName(
      number: 23,
      arabic: 'الرَّافِعُ',
      transliteration: 'Ar-Rafi\'',
      meaningAr: 'الذي يرفع المؤمنين بالطاعة والعلم.',
    ),
    DivineName(
      number: 24,
      arabic: 'الْمُعِزُّ',
      transliteration: 'Al-Mu\'izz',
      meaningAr: 'الذي يهب العزّ لمن يشاء.',
    ),
    DivineName(
      number: 25,
      arabic: 'الْمُذِلُّ',
      transliteration: 'Al-Mudhill',
      meaningAr: 'الذي يذلّ من يشاء بعدله.',
    ),
    DivineName(
      number: 26,
      arabic: 'السَّمِيعُ',
      transliteration: 'As-Samee\'',
      meaningAr: 'الذي يسمع كل شيء، لا يخفى عليه سرّ.',
    ),
    DivineName(
      number: 27,
      arabic: 'الْبَصِيرُ',
      transliteration: 'Al-Baseer',
      meaningAr: 'الذي يرى كل شيء وإن دقّ وخفي.',
    ),
    DivineName(
      number: 28,
      arabic: 'الْحَكَمُ',
      transliteration: 'Al-Hakam',
      meaningAr: 'الحاكم الذي لا معقّب لحكمه.',
    ),
    DivineName(
      number: 29,
      arabic: 'الْعَدْلُ',
      transliteration: 'Al-\'Adl',
      meaningAr: 'الذي لا يجور ولا يظلم مثقال ذرة.',
    ),
    DivineName(
      number: 30,
      arabic: 'اللَّطِيفُ',
      transliteration: 'Al-Lateef',
      meaningAr: 'الرفيق بعباده، العالم بدقائق الأمور.',
    ),
    DivineName(
      number: 31,
      arabic: 'الْخَبِيرُ',
      transliteration: 'Al-Khabeer',
      meaningAr: 'العليم ببواطن الأشياء وخفاياها.',
    ),
    DivineName(
      number: 32,
      arabic: 'الْحَلِيمُ',
      transliteration: 'Al-Haleem',
      meaningAr: 'الذي لا يعاجل بالعقوبة مع القدرة.',
    ),
    DivineName(
      number: 33,
      arabic: 'الْعَظِيمُ',
      transliteration: 'Al-\'Azeem',
      meaningAr: 'ذو العظمة التي لا تُدرك كنهها العقول.',
    ),
    DivineName(
      number: 34,
      arabic: 'الْغَفُورُ',
      transliteration: 'Al-Ghafoor',
      meaningAr: 'الساتر للذنوب، الماحي لأثرها.',
    ),
    DivineName(
      number: 35,
      arabic: 'الشَّكُورُ',
      transliteration: 'Ash-Shakoor',
      meaningAr: 'الذي يجزي على القليل بالكثير.',
    ),
    DivineName(
      number: 36,
      arabic: 'الْعَلِيُّ',
      transliteration: 'Al-\'Aliyy',
      meaningAr: 'العالي على خلقه بذاته وقدره وقهره.',
    ),
    DivineName(
      number: 37,
      arabic: 'الْكَبِيرُ',
      transliteration: 'Al-Kabeer',
      meaningAr: 'الذي كل شيء دونه صغير.',
    ),
    DivineName(
      number: 38,
      arabic: 'الْحَفِيظُ',
      transliteration: 'Al-Hafeez',
      meaningAr: 'الحافظ لخلقه وأعمالهم، لا يفوته شيء.',
    ),
    DivineName(
      number: 39,
      arabic: 'الْمُقِيتُ',
      transliteration: 'Al-Muqeet',
      meaningAr: 'الذي يقيت الخلق ويقدّر أقواتهم.',
    ),
    DivineName(
      number: 40,
      arabic: 'الْحَسِيبُ',
      transliteration: 'Al-Haseeb',
      meaningAr: 'الكافي عباده، المحاسب لهم على أعمالهم.',
    ),
    DivineName(
      number: 41,
      arabic: 'الْجَلِيلُ',
      transliteration: 'Al-Jaleel',
      meaningAr: 'الموصوف بصفات الجلال والعظمة.',
    ),
    DivineName(
      number: 42,
      arabic: 'الْكَرِيمُ',
      transliteration: 'Al-Kareem',
      meaningAr: 'الجواد المعطي الذي لا ينفد عطاؤه.',
    ),
    DivineName(
      number: 43,
      arabic: 'الرَّقِيبُ',
      transliteration: 'Ar-Raqeeb',
      meaningAr: 'المطّلع على خلقه، الحافظ لأعمالهم.',
    ),
    DivineName(
      number: 44,
      arabic: 'الْمُجِيبُ',
      transliteration: 'Al-Mujeeb',
      meaningAr: 'الذي يجيب دعاء الداعي إذا دعاه.',
    ),
    DivineName(
      number: 45,
      arabic: 'الْوَاسِعُ',
      transliteration: 'Al-Wasi\'',
      meaningAr: 'الواسع في علمه ورحمته وفضله.',
    ),
    DivineName(
      number: 46,
      arabic: 'الْحَكِيمُ',
      transliteration: 'Al-Hakeem',
      meaningAr: 'الذي يضع الأشياء مواضعها بحكمته.',
    ),
    DivineName(
      number: 47,
      arabic: 'الْوَدُودُ',
      transliteration: 'Al-Wadood',
      meaningAr: 'المحبّ لعباده الصالحين، المحبوب لهم.',
    ),
    DivineName(
      number: 48,
      arabic: 'الْمَجِيدُ',
      transliteration: 'Al-Majeed',
      meaningAr: 'ذو الشرف والكرم التام.',
    ),
    DivineName(
      number: 49,
      arabic: 'الْبَاعِثُ',
      transliteration: 'Al-Ba\'ith',
      meaningAr: 'الذي يبعث الخلق يوم القيامة.',
    ),
    DivineName(
      number: 50,
      arabic: 'الشَّهِيدُ',
      transliteration: 'Ash-Shaheed',
      meaningAr: 'الحاضر الذي لا يغيب عنه شيء.',
    ),
    DivineName(
      number: 51,
      arabic: 'الْحَقُّ',
      transliteration: 'Al-Haqq',
      meaningAr: 'الثابت الذي لا يزول، وجوده حق.',
    ),
    DivineName(
      number: 52,
      arabic: 'الْوَكِيلُ',
      transliteration: 'Al-Wakeel',
      meaningAr: 'الكفيل بأرزاق العباد، المتولي لأمورهم.',
    ),
    DivineName(
      number: 53,
      arabic: 'الْقَوِيُّ',
      transliteration: 'Al-Qawiyy',
      meaningAr: 'التام القدرة، لا يلحقه عجز.',
    ),
    DivineName(
      number: 54,
      arabic: 'الْمَتِينُ',
      transliteration: 'Al-Mateen',
      meaningAr: 'الشديد القوة الذي لا تنقطع قوته.',
    ),
    DivineName(
      number: 55,
      arabic: 'الْوَلِيُّ',
      transliteration: 'Al-Waliyy',
      meaningAr: 'الناصر لعباده المؤمنين، المتولي أمورهم.',
    ),
    DivineName(
      number: 56,
      arabic: 'الْحَمِيدُ',
      transliteration: 'Al-Hameed',
      meaningAr: 'المحمود على كل حال، المستحق للثناء.',
    ),
    DivineName(
      number: 57,
      arabic: 'الْمُحْصِي',
      transliteration: 'Al-Muhsee',
      meaningAr: 'الذي أحصى كل شيء عددًا.',
    ),
    DivineName(
      number: 58,
      arabic: 'الْمُبْدِئُ',
      transliteration: 'Al-Mubdi\'',
      meaningAr: 'الذي بدأ الخلق ابتداءً.',
    ),
    DivineName(
      number: 59,
      arabic: 'الْمُعِيدُ',
      transliteration: 'Al-Mu\'eed',
      meaningAr: 'الذي يعيد الخلق بعد فنائهم.',
    ),
    DivineName(
      number: 60,
      arabic: 'الْمُحْيِي',
      transliteration: 'Al-Muhyee',
      meaningAr: 'الذي يهب الحياة لكل حيّ.',
    ),
    DivineName(
      number: 61,
      arabic: 'الْمُمِيتُ',
      transliteration: 'Al-Mumeet',
      meaningAr: 'الذي كتب الموت على خلقه.',
    ),
    DivineName(
      number: 62,
      arabic: 'الْحَيُّ',
      transliteration: 'Al-Hayy',
      meaningAr: 'الحي حياة كاملة لا يعتريها موت.',
    ),
    DivineName(
      number: 63,
      arabic: 'الْقَيُّومُ',
      transliteration: 'Al-Qayyoom',
      meaningAr: 'القائم بنفسه، المقيم لكل ما سواه.',
    ),
    DivineName(
      number: 64,
      arabic: 'الْوَاجِدُ',
      transliteration: 'Al-Wajid',
      meaningAr: 'الغني الذي لا يعوزه شيء.',
    ),
    DivineName(
      number: 65,
      arabic: 'الْمَاجِدُ',
      transliteration: 'Al-Majid',
      meaningAr: 'ذو المجد والشرف والكرم.',
    ),
    DivineName(
      number: 66,
      arabic: 'الْوَاحِدُ',
      transliteration: 'Al-Wahid',
      meaningAr: 'الفرد الذي لا شريك له.',
    ),
    DivineName(
      number: 67,
      arabic: 'الْأَحَدُ',
      transliteration: 'Al-Ahad',
      meaningAr: 'المتفرد في ذاته وصفاته وأفعاله.',
    ),
    DivineName(
      number: 68,
      arabic: 'الصَّمَدُ',
      transliteration: 'As-Samad',
      meaningAr: 'السيد الذي تُقصد إليه الحوائج.',
    ),
    DivineName(
      number: 69,
      arabic: 'الْقَادِرُ',
      transliteration: 'Al-Qadir',
      meaningAr: 'الذي لا يعجزه شيء في الأرض ولا السماء.',
    ),
    DivineName(
      number: 70,
      arabic: 'الْمُقْتَدِرُ',
      transliteration: 'Al-Muqtadir',
      meaningAr: 'التام القدرة على كل مقدور.',
    ),
    DivineName(
      number: 71,
      arabic: 'الْمُقَدِّمُ',
      transliteration: 'Al-Muqaddim',
      meaningAr: 'الذي يقدّم من يشاء بفضله.',
    ),
    DivineName(
      number: 72,
      arabic: 'الْمُؤَخِّرُ',
      transliteration: 'Al-Mu\'akhkhir',
      meaningAr: 'الذي يؤخّر من يشاء بعدله.',
    ),
    DivineName(
      number: 73,
      arabic: 'الْأَوَّلُ',
      transliteration: 'Al-Awwal',
      meaningAr: 'الذي ليس قبله شيء.',
    ),
    DivineName(
      number: 74,
      arabic: 'الْآخِرُ',
      transliteration: 'Al-Akhir',
      meaningAr: 'الذي ليس بعده شيء.',
    ),
    DivineName(
      number: 75,
      arabic: 'الظَّاهِرُ',
      transliteration: 'Az-Zahir',
      meaningAr: 'الذي ليس فوقه شيء، الظاهر بآياته.',
    ),
    DivineName(
      number: 76,
      arabic: 'الْبَاطِنُ',
      transliteration: 'Al-Batin',
      meaningAr: 'الذي ليس دونه شيء، العالم بالخفايا.',
    ),
    DivineName(
      number: 77,
      arabic: 'الْوَالِي',
      transliteration: 'Al-Walee',
      meaningAr: 'المالك للأشياء، المتصرف فيها.',
    ),
    DivineName(
      number: 78,
      arabic: 'الْمُتَعَالِي',
      transliteration: 'Al-Muta\'ali',
      meaningAr: 'المنزَّه عن صفات المخلوقين.',
    ),
    DivineName(
      number: 79,
      arabic: 'الْبَرُّ',
      transliteration: 'Al-Barr',
      meaningAr: 'المحسن إلى عباده، الواسع البرّ.',
    ),
    DivineName(
      number: 80,
      arabic: 'التَّوَّابُ',
      transliteration: 'At-Tawwab',
      meaningAr: 'الذي يوفّق للتوبة ثم يقبلها.',
    ),
    DivineName(
      number: 81,
      arabic: 'الْمُنْتَقِمُ',
      transliteration: 'Al-Muntaqim',
      meaningAr: 'الذي ينتصف من الظالمين بعدله.',
    ),
    DivineName(
      number: 82,
      arabic: 'الْعَفُوُّ',
      transliteration: 'Al-\'Afuww',
      meaningAr: 'الذي يمحو الذنب فلا يبقي له أثرًا.',
    ),
    DivineName(
      number: 83,
      arabic: 'الرَّءُوفُ',
      transliteration: 'Ar-Ra\'oof',
      meaningAr: 'شديد الرحمة والرأفة بعباده.',
    ),
    DivineName(
      number: 84,
      arabic: 'مَالِكُ الْمُلْكِ',
      transliteration: 'Malik al-Mulk',
      meaningAr: 'المالك للملك كله، يؤتيه من يشاء.',
    ),
    DivineName(
      number: 85,
      arabic: 'ذُو الْجَلَالِ وَالْإِكْرَامِ',
      transliteration: 'Dhul-Jalali wal-Ikram',
      meaningAr: 'ذو العظمة والكرم، أهل أن يُعظَّم ويُكرَم.',
    ),
    DivineName(
      number: 86,
      arabic: 'الْمُقْسِطُ',
      transliteration: 'Al-Muqsit',
      meaningAr: 'العادل في حكمه، المنصف للمظلوم.',
    ),
    DivineName(
      number: 87,
      arabic: 'الْجَامِعُ',
      transliteration: 'Al-Jami\'',
      meaningAr: 'الذي يجمع الخلق ليوم لا ريب فيه.',
    ),
    DivineName(
      number: 88,
      arabic: 'الْغَنِيُّ',
      transliteration: 'Al-Ghaniyy',
      meaningAr: 'المستغني عن كل ما سواه.',
    ),
    DivineName(
      number: 89,
      arabic: 'الْمُغْنِي',
      transliteration: 'Al-Mughnee',
      meaningAr: 'الذي يغني من يشاء من خلقه.',
    ),
    DivineName(
      number: 90,
      arabic: 'الْمَانِعُ',
      transliteration: 'Al-Mani\'',
      meaningAr: 'الذي يمنع ما شاء عمّن شاء بحكمته.',
    ),
    DivineName(
      number: 91,
      arabic: 'الضَّارُّ',
      transliteration: 'Ad-Darr',
      meaningAr: 'الذي لا يقع ضرّ إلا بإذنه.',
    ),
    DivineName(
      number: 92,
      arabic: 'النَّافِعُ',
      transliteration: 'An-Nafi\'',
      meaningAr: 'الذي لا يصل نفع إلا منه.',
    ),
    DivineName(
      number: 93,
      arabic: 'النُّورُ',
      transliteration: 'An-Noor',
      meaningAr: 'الهادي، ونور السماوات والأرض.',
    ),
    DivineName(
      number: 94,
      arabic: 'الْهَادِي',
      transliteration: 'Al-Hadee',
      meaningAr: 'الذي يهدي من يشاء إلى صراطه.',
    ),
    DivineName(
      number: 95,
      arabic: 'الْبَدِيعُ',
      transliteration: 'Al-Badee\'',
      meaningAr: 'مبدع الخلق على غير مثال سابق.',
    ),
    DivineName(
      number: 96,
      arabic: 'الْبَاقِي',
      transliteration: 'Al-Baqee',
      meaningAr: 'الدائم الذي لا يفنى.',
    ),
    DivineName(
      number: 97,
      arabic: 'الْوَارِثُ',
      transliteration: 'Al-Warith',
      meaningAr: 'الباقي بعد فناء خلقه، يرث الأرض ومن عليها.',
    ),
    DivineName(
      number: 98,
      arabic: 'الرَّشِيدُ',
      transliteration: 'Ar-Rasheed',
      meaningAr: 'المرشد إلى الخير، الذي أفعاله كلها رشد.',
    ),
    DivineName(
      number: 99,
      arabic: 'الصَّبُورُ',
      transliteration: 'As-Saboor',
      meaningAr: 'الذي لا يعاجل العصاة بالعقوبة.',
    ),
  ];

  static DivineName byNumber(int number) => all[number - 1];

  /// Names matching [query], typed with or without the definite article and
  /// with or without diacritics.
  static List<DivineName> search(String query) {
    final needle = bare(query);
    if (needle.isEmpty) {
      return all;
    }
    return all
        .where(
          (name) =>
              bare(name.arabic).contains(needle) ||
              bare(name.meaningAr).contains(needle) ||
              name.transliteration.toLowerCase().contains(
                query.trim().toLowerCase(),
              ),
        )
        .toList();
  }

  /// Strip diacritics and the definite article so "رحمن" finds "الرَّحْمَنُ".
  static String bare(String value) {
    final stripped =
        value
            .replaceAll(RegExp('[ً-ْٰ]'), '')
            .replaceAll(RegExp('[آأإٱ]'), 'ا')
            .replaceAll('ة', 'ه')
            .replaceAll('ى', 'ي')
            .trim();
    return stripped.startsWith('ال') ? stripped.substring(2) : stripped;
  }
}
