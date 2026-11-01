/// أدعية الرزق من السنة النبوية
///
/// Supplications for provision and relief from debt, from the Sunnah and
/// narrations, gathered here so the morning notification can pick one and
/// the full page can show them all.
library;

class RizqDua {
  const RizqDua({
    required this.id,
    required this.textAr,
    required this.textEn,
    required this.virtue,
    required this.reference,
  });

  final int id;
  final String textAr;
  final String textEn;
  final String virtue;
  final String reference;
}

class RizqDuas {
  RizqDuas._();

  static const List<RizqDua> all = [
    RizqDua(
      id: 1,
      textAr:
          'اللَّهمَّ ربَّ السَّمواتِ السَّبْعِ وربَّ العرشِ العظيمِ، ربَّنا وربَّ كلِّ شيءٍ، مُنْزِلَ التَّوراةِ والإنجيلِ، والفُرقانِ، فالِقَ الحَبِّ والنَّوَى، أعوذُ بِكَ مِن شرِّ كُلِّ شيءٍ أنتَ آخِذٌ بناصيتِهِ، أنتَ الأوَّلُ فليسَ قَبْلَكَ شيءٌ، وأنتَ الآخِرُ فليسَ بعدَكَ شيءٌ، وأنتَ الظَّاهِرُ فليسَ فَوْقَكَ شيءٌ، وأنتَ الباطِنُ فليسَ دونَكَ شيءٌ، اقضِ عنَّا الدَّينَ وأَغْنِنا مِن الفقرِ',
      textEn:
          'O Allah, Lord of the seven heavens and Lord of the Mighty Throne, our Lord and Lord of everything, Revealer of the Torah, the Gospel, and the Criterion, Splitter of the grain and the date-stone, I seek refuge in You from the evil of everything whose forelock You seize. You are the First, nothing is before You; You are the Last, nothing is after You; You are the Manifest, nothing is above You; You are the Hidden, nothing is beyond You. Settle our debt and enrich us from poverty',
      virtue: 'من قالها عند النوم قضى الله عنه دينه وأغناه من الفقر',
      reference: 'صحيح مسلم',
    ),
    RizqDua(
      id: 2,
      textAr:
          'اللَّهمَّ إني أعوذُ بك من الهمِّ والحزَنِ، وأعوذُ بك من العجزِ والكسلِ، وأعوذُ بك من الجبنِ والبخلِ، وأعوذُ بك من غلبةِ الدينِ وقهرِ الرجالِ',
      textEn:
          'O Allah, I seek refuge in You from worry and grief, from incapacity and laziness, from cowardice and miserliness, and from being overcome by debt and from being overpowered by men',
      virtue: 'من الأدعية الجامعة التي كان النبي ﷺ يكثر منها',
      reference: 'صحيح البخاري',
    ),
    RizqDua(
      id: 3,
      textAr: 'اللهم اكفني بحلالك عن حرامك، وأغنني بفضلك عمن سواك',
      textEn:
          'O Allah, make what is lawful enough for me, as opposed to what is unlawful, and spare me by Your grace, of need of others',
      virtue: 'دعاء جامع لطلب الرزق الحلال والاستغناء بالله',
      reference: 'سنن الترمذي',
    ),
    RizqDua(
      id: 4,
      textAr:
          'اللهم إن كان رزقي في السماء فأنزله، وإن كان في الأرض فأخرجه، وإن كان بعيدًا فقربه، وإن كان قريبًا فيسره، وإن كان قليلًا فكثره، وإن كان كثيراً فبارك لي فيه',
      textEn:
          'O Allah, if my provision is in the sky, send it down; if it is in the earth, bring it forth; if it is far, bring it near; if it is near, make it easy; if it is little, increase it; if it is much, bless it for me',
      virtue: 'دعاء جامع لتيسير الرزق من جميع الجهات',
      reference: 'مأثور',
    ),
    RizqDua(
      id: 5,
      textAr: 'اللهم ارزقني من حيث أحتسب ومن حيث لا أحتسب',
      textEn:
          'O Allah, grant me provision from where I expect and from where I do not expect',
      virtue: 'طلب الرزق من الجهات المتوقعة وغير المتوقعة',
      reference: 'مأثور',
    ),
    RizqDua(
      id: 6,
      textAr: 'اللهم إني أسألك من فضلك ورحمتك، فإنه لا يملكها إلا أنت',
      textEn:
          'O Allah, I ask You for Your grace and mercy, for no one possesses them but You',
      virtue: 'طلب الفضل والرحمة من الله تعالى',
      reference: 'مأثور',
    ),
    RizqDua(
      id: 7,
      textAr: 'اللهم بارك لنا في رزقنا وبارك لنا في أعمارنا واغفر لنا ذنوبنا',
      textEn:
          'O Allah, bless us in our provision, bless us in our lifetimes, and forgive us our sins',
      virtue: 'طلب البركة في الرزق والعمر',
      reference: 'مأثور',
    ),
    RizqDua(
      id: 8,
      textAr:
          'اللهم اجعل رزقي واسعاً حلالاً طيباً من غير كد ولا تعب ولا منة من أحد',
      textEn:
          'O Allah, make my provision abundant, lawful, wholesome, without hardship, toil, or favor from anyone',
      virtue: 'طلب الرزق الواسع الحلال الطيب',
      reference: 'مأثور',
    ),
    RizqDua(
      id: 9,
      textAr: 'حسبي الله لا إله إلا هو عليه توكلت وهو رب العرش العظيم',
      textEn:
          'Allah is sufficient for me; there is no god but Him. In Him I put my trust, and He is the Lord of the Mighty Throne',
      virtue: 'من قالها سبع مرات كفاه الله ما أهمه',
      reference: 'سنن أبي داود',
    ),
    RizqDua(
      id: 10,
      textAr: 'اللهم افتح لي أبواب رزقك وبارك لي فيما رزقتني',
      textEn:
          'O Allah, open for me the doors of Your provision and bless me in what You have provided',
      virtue: 'فتح أبواب الرزق من الله تعالى',
      reference: 'مأثور',
    ),
  ];

  /// Pick a random dua for the morning notification.
  static RizqDua random() {
    final now = DateTime.now();
    final index = (now.day + now.month + now.year) % all.length;
    return all[index];
  }
}
