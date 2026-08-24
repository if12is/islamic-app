/// One wording of the prayer upon the Prophet ﷺ.
class SalawatForm {
  const SalawatForm({
    required this.id,
    required this.textAr,
    required this.sourceAr,
    this.noteAr,
  });

  final String id;
  final String textAr;

  /// Where the wording comes from — every one of these is narrated.
  final String sourceAr;

  final String? noteAr;
}

/// Wordings taught in the sunnah, and why each is here.
///
/// Only narrated forms are listed. Invented wordings circulate widely and some
/// carry extravagant promises attached to a count; none of that is included,
/// because a counter that rewards a fabricated formula is worse than no
/// counter at all.
class SalawatForms {
  SalawatForms._();

  /// The virtue the screen quotes, which is agreed upon.
  static const String virtueAr =
      'مَنْ صَلَّى عَلَيَّ صَلَاةً وَاحِدَةً صَلَّى اللَّهُ عَلَيْهِ بِهَا عَشْرًا.';

  static const String virtueSourceAr = 'رواه مسلم';

  /// Friday carries an added instruction.
  static const String fridayAr =
      'أَكْثِرُوا عَلَيَّ مِنَ الصَّلَاةِ يَوْمَ الْجُمُعَةِ، فَإِنَّ صَلَاتَكُمْ '
      'مَعْرُوضَةٌ عَلَيَّ.';

  static const String fridaySourceAr = 'رواه أبو داود، وصححه الألباني';

  static const List<SalawatForm> all = [
    SalawatForm(
      id: 'ibrahimiyyah',
      textAr:
          'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ، كَمَا صَلَّيْتَ عَلَى '
          'إِبْرَاهِيمَ وَعَلَى آلِ إِبْرَاهِيمَ، إِنَّكَ حَمِيدٌ مَجِيدٌ. '
          'اللَّهُمَّ بَارِكْ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ، كَمَا بَارَكْتَ عَلَى '
          'إِبْرَاهِيمَ وَعَلَى آلِ إِبْرَاهِيمَ، إِنَّكَ حَمِيدٌ مَجِيدٌ.',
      sourceAr: 'متفق عليه — البخاري ومسلم',
      noteAr: 'الصيغة التي علّمها النبي ﷺ أصحابه حين سألوه كيف يصلّون عليه.',
    ),
    SalawatForm(
      id: 'short',
      textAr: 'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ.',
      sourceAr: 'مختصرة من الصيغة الثابتة',
      noteAr: 'قصيرة تصلح للتكرار في المشي والعمل.',
    ),
    SalawatForm(
      id: 'wa_barik',
      textAr:
          'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ وَعَلَى آلِ مُحَمَّدٍ وَبَارِكْ وَسَلِّمْ.',
      sourceAr: 'من ألفاظ الصيغة الإبراهيمية',
    ),
    SalawatForm(
      id: 'abdik',
      textAr:
          'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ عَبْدِكَ وَرَسُولِكَ، وَصَلِّ عَلَى '
          'الْمُؤْمِنِينَ وَالْمُؤْمِنَاتِ وَالْمُسْلِمِينَ وَالْمُسْلِمَاتِ.',
      sourceAr: 'رواه البخاري',
    ),
  ];

  static SalawatForm byId(String id) =>
      all.firstWhere((form) => form.id == id, orElse: () => all.first);
}
