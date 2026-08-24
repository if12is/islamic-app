/// The voices that can be played one ayah at a time.
///
/// This is a different list from the whole-surah one, and the difference is
/// not a shortcoming — it is what the two are for. A whole-surah recording is
/// a single file with no seam at the ayah, so nothing that needs to stop,
/// repeat or caption one verse can use it. Per-ayah audio is a separate corpus
/// with its own, shorter list of reciters.
///
/// Every entry below was requested and answered before it was written down.
/// The list this replaced had seven voices, one of which — Sudais — the old
/// CDN refuses outright with a 403, so the verse player and the memorisation
/// loop had been silently broken on it.
library;

/// One voice, recorded ayah by ayah.
class VerseReciter {
  const VerseReciter({
    required this.id,
    required this.nameAr,
    required this.folder,
    this.styleAr = '',
    this.lowFolder,
  });

  /// Stable id kept in preferences and backups.
  final String id;

  final String nameAr;

  /// "مجوَّد", "رواية ورش", … — empty for plain murattal.
  final String styleAr;

  /// The directory on the per-ayah host.
  final String folder;

  /// A smaller recording of the same voice, where the host publishes one.
  ///
  /// This is what the data saver actually turns down. The host stores each
  /// bitrate as its own directory rather than as a parameter, so halving the
  /// bytes means choosing a different folder, not editing a number in the URL.
  final String? lowFolder;

  bool get hasLowQuality => lowFolder != null;

  String get label => styleAr.isEmpty ? nameAr : '$nameAr — $styleAr';

  /// `.../data/<folder>/001001.mp3`
  String urlFor(int surahNumber, int verseNumber, {bool small = false}) {
    final s = surahNumber.toString().padLeft(3, '0');
    final v = verseNumber.toString().padLeft(3, '0');
    final directory = small ? (lowFolder ?? folder) : folder;
    return '${VerseReciters.host}$directory/$s$v.mp3';
  }
}

/// The catalogue.
class VerseReciters {
  VerseReciters._();

  static const String host = 'https://everyayah.com/data/';

  /// Where a saved choice from the old seven-voice list should land.
  ///
  /// Three of those seven ids were also whole-surah edition codes, so they are
  /// still valid there; this only redirects what the verse player asks for.
  static const Map<String, String> legacyIds = {
    'ar.alafasy': 'alafasy',
    'ar.mahermuaiqly': 'maher',
    'ar.husary': 'husary',
    'ar.minshawi': 'minshawi',
    'ar.abdurrahmaansudais': 'sudais',
    'ar.shaatree': 'shaatree',
    'ar.ahmedajamy': 'ajamy',
  };

  /// Arabic murattal and mujawwad, one entry per voice.
  ///
  /// Translations and word-by-word recordings the host also carries are left
  /// out: this list feeds a Qur'an player, and an English rendering in it
  /// would be a different thing wearing the same list.
  static const List<VerseReciter> all = [
    VerseReciter(
      id: 'alafasy',
      nameAr: 'مشاري راشد العفاسي',
      folder: 'Alafasy_128kbps',
      lowFolder: 'Alafasy_64kbps',
    ),
    VerseReciter(
      id: 'abdulbasit',
      nameAr: 'عبد الباسط عبد الصمد',
      folder: 'Abdul_Basit_Murattal_192kbps',
      lowFolder: 'Abdul_Basit_Murattal_64kbps',
      styleAr: 'مرتَّل',
    ),
    VerseReciter(
      id: 'abdulbasit-mujawwad',
      nameAr: 'عبد الباسط عبد الصمد',
      folder: 'Abdul_Basit_Mujawwad_128kbps',
      styleAr: 'مجوَّد',
    ),
    VerseReciter(
      id: 'sudais',
      nameAr: 'عبد الرحمن السديس',
      folder: 'Abdurrahmaan_As-Sudais_192kbps',
      lowFolder: 'Abdurrahmaan_As-Sudais_64kbps',
    ),
    VerseReciter(
      id: 'shuraim',
      nameAr: 'سعود الشريم',
      folder: 'Saood_ash-Shuraym_128kbps',
      lowFolder: 'Saood_ash-Shuraym_64kbps',
    ),
    VerseReciter(
      id: 'husary',
      nameAr: 'محمود خليل الحصري',
      folder: 'Husary_128kbps',
      lowFolder: 'Husary_64kbps',
      styleAr: 'مرتَّل',
    ),
    VerseReciter(
      id: 'husary-mujawwad',
      nameAr: 'محمود خليل الحصري',
      folder: 'Husary_128kbps_Mujawwad',
      lowFolder: 'Husary_Mujawwad_64kbps',
      styleAr: 'مجوَّد',
    ),
    VerseReciter(
      id: 'husary-muallim',
      nameAr: 'محمود خليل الحصري',
      folder: 'Husary_Muallim_128kbps',
      styleAr: 'المعلِّم',
    ),
    VerseReciter(
      id: 'minshawi',
      nameAr: 'محمد صديق المنشاوي',
      folder: 'Minshawy_Murattal_128kbps',
      styleAr: 'مرتَّل',
    ),
    VerseReciter(
      id: 'minshawi-mujawwad',
      nameAr: 'محمد صديق المنشاوي',
      folder: 'Minshawy_Mujawwad_192kbps',
      lowFolder: 'Minshawy_Mujawwad_64kbps',
      styleAr: 'مجوَّد',
    ),
    VerseReciter(
      id: 'maher',
      nameAr: 'ماهر المعيقلي',
      folder: 'MaherAlMuaiqly128kbps',
      lowFolder: 'Maher_AlMuaiqly_64kbps',
    ),
    VerseReciter(
      id: 'shaatree',
      nameAr: 'أبو بكر الشاطري',
      folder: 'Abu_Bakr_Ash-Shaatree_128kbps',
      lowFolder: 'Abu_Bakr_Ash-Shaatree_64kbps',
    ),
    VerseReciter(
      id: 'ajamy',
      nameAr: 'أحمد بن علي العجمي',
      folder: 'ahmed_ibn_ali_al_ajamy_128kbps',
      lowFolder: 'Ahmed_ibn_Ali_al-Ajamy_64kbps_QuranExplorer.Com',
    ),
    VerseReciter(
      id: 'hudhaify',
      nameAr: 'علي بن عبد الرحمن الحذيفي',
      folder: 'Hudhaify_128kbps',
      lowFolder: 'Hudhaify_64kbps',
    ),
    VerseReciter(
      id: 'basfar',
      nameAr: 'عبد الله بصفر',
      folder: 'Abdullah_Basfar_192kbps',
      lowFolder: 'Abdullah_Basfar_64kbps',
    ),
    VerseReciter(
      id: 'hanirifai',
      nameAr: 'هاني الرفاعي',
      folder: 'Hani_Rifai_192kbps',
      lowFolder: 'Hani_Rifai_64kbps',
    ),
    VerseReciter(
      id: 'ghamadi',
      nameAr: 'سعد الغامدي',
      folder: 'Ghamadi_40kbps',
    ),
    VerseReciter(
      id: 'tablawi',
      nameAr: 'محمد محمود الطبلاوي',
      folder: 'Mohammad_al_Tablaway_128kbps',
      lowFolder: 'Mohammad_al_Tablaway_64kbps',
    ),
    VerseReciter(
      id: 'ayyoub',
      nameAr: 'محمد أيوب',
      folder: 'Muhammad_Ayyoub_128kbps',
      lowFolder: 'Muhammad_Ayyoub_64kbps',
    ),
    VerseReciter(
      id: 'jibreel',
      nameAr: 'محمد جبريل',
      folder: 'Muhammad_Jibreel_128kbps',
      lowFolder: 'Muhammad_Jibreel_64kbps',
    ),
    VerseReciter(
      id: 'mustafaismail',
      nameAr: 'مصطفى إسماعيل',
      folder: 'Mustafa_Ismail_48kbps',
    ),
    VerseReciter(
      id: 'ibrahimakhdar',
      nameAr: 'إبراهيم الأخضر',
      folder: 'Ibrahim_Akhdar_32kbps',
    ),
    VerseReciter(
      id: 'juhaynee',
      nameAr: 'عبد الله عواد الجهني',
      folder: 'Abdullaah_3awwaad_Al-Juhaynee_128kbps',
    ),
    VerseReciter(
      id: 'budair',
      nameAr: 'صلاح البدير',
      folder: 'Salah_Al_Budair_128kbps',
    ),
    VerseReciter(
      id: 'matroud',
      nameAr: 'عبد الله المطرود',
      folder: 'Abdullah_Matroud_128kbps',
    ),
    VerseReciter(
      id: 'qatami',
      nameAr: 'ناصر القطامي',
      folder: 'Nasser_Alqatami_128kbps',
    ),
    VerseReciter(
      id: 'dussary',
      nameAr: 'ياسر الدوسري',
      folder: 'Yasser_Ad-Dussary_128kbps',
    ),
    VerseReciter(
      id: 'qahtani',
      nameAr: 'خالد عبد الله القحطاني',
      folder: 'Khaalid_Abdullaah_al-Qahtaanee_192kbps',
    ),
    VerseReciter(
      id: 'muhsinalqasim',
      nameAr: 'محسن القاسم',
      folder: 'Muhsin_Al_Qasim_192kbps',
    ),
    VerseReciter(
      id: 'bukhatir',
      nameAr: 'صلاح بو خاطر',
      folder: 'Salaah_AbdulRahman_Bukhatir_128kbps',
    ),
    VerseReciter(
      id: 'banna',
      nameAr: 'محمود علي البنا',
      folder: 'mahmoud_ali_al_banna_32kbps',
    ),
    VerseReciter(
      id: 'neana',
      nameAr: 'أحمد نعينع',
      folder: 'Ahmed_Neana_128kbps',
    ),
    VerseReciter(
      id: 'abdulkareem',
      nameAr: 'محمد عبد الكريم',
      folder: 'Muhammad_AbdulKareem_128kbps',
    ),
    VerseReciter(
      id: 'tunaiji',
      nameAr: 'خليفة الطنيجي',
      folder: 'khalefa_al_tunaiji_64kbps',
    ),
    VerseReciter(
      id: 'suesy',
      nameAr: 'علي حجاج السويسي',
      folder: 'Ali_Hajjaj_AlSuesy_128kbps',
    ),
    VerseReciter(
      id: 'sahlyassin',
      nameAr: 'سهل ياسين',
      folder: 'Sahl_Yassin_128kbps',
    ),
    VerseReciter(
      id: 'azizalili',
      nameAr: 'عزيز عليلي',
      folder: 'aziz_alili_128kbps',
    ),
    VerseReciter(
      id: 'yasersalamah',
      nameAr: 'ياسر سلامة',
      folder: 'Yaser_Salamah_128kbps',
    ),
    VerseReciter(
      id: 'alaqimy',
      nameAr: 'أكرم العلاقمي',
      folder: 'Akram_AlAlaqimy_128kbps',
    ),
    VerseReciter(
      id: 'alijaber',
      nameAr: 'علي جابر',
      folder: 'Ali_Jaber_64kbps',
    ),
    VerseReciter(
      id: 'faresabbad',
      nameAr: 'فارس عباد',
      folder: 'Fares_Abbad_64kbps',
    ),
    VerseReciter(
      id: 'aymansowaid',
      nameAr: 'أيمن سويد',
      folder: 'Ayman_Sowaid_64kbps',
      styleAr: 'تعليمي',
    ),
    VerseReciter(
      id: 'abdulsamad-qe',
      nameAr: 'عبد الصمد',
      folder: 'AbdulSamad_64kbps_QuranExplorer.Com',
    ),
    VerseReciter(
      id: 'menshawi-teacher',
      nameAr: 'محمد صديق المنشاوي',
      folder: 'Menshawi_32kbps',
      styleAr: 'المعلِّم',
    ),
    // The Warsh recordings are a different reading, not a different voice, so
    // they are labelled by riwayah — someone who wants Hafs must not land on
    // one of these by accident.
    VerseReciter(
      id: 'warsh-dosary',
      nameAr: 'إبراهيم الدوسري',
      folder: 'warsh/warsh_ibrahim_aldosary_128kbps',
      styleAr: 'رواية ورش',
    ),
    VerseReciter(
      id: 'warsh-jazaery',
      nameAr: 'ياسين الجزائري',
      folder: 'warsh/warsh_yassin_al_jazaery_64kbps',
      styleAr: 'رواية ورش',
    ),
    VerseReciter(
      id: 'warsh-abdulbasit',
      nameAr: 'عبد الباسط عبد الصمد',
      folder: 'warsh/warsh_Abdul_Basit_128kbps',
      styleAr: 'رواية ورش',
    ),
  ];

  static const String defaultId = 'alafasy';

  /// The reciter for [id], accepting an id from the old list too.
  static VerseReciter byId(String id) {
    final resolved = legacyIds[id] ?? id;
    for (final reciter in all) {
      if (reciter.id == resolved) {
        return reciter;
      }
    }
    return all.first;
  }

  /// Whether [id] names a voice that has per-ayah audio.
  static bool has(String id) {
    final resolved = legacyIds[id] ?? id;
    return all.any((reciter) => reciter.id == resolved);
  }

  /// The id to actually use — the saved one when it has verse audio, and the
  /// default when it does not. A whole-surah catalogue id such as
  /// `mp3quran:92:92` has no per-ayah files and would 404 every verse.
  static String resolve(String id) =>
      has(id) ? (legacyIds[id] ?? id) : defaultId;

  /// Name search that ignores diacritics and alif shapes.
  static List<VerseReciter> search(String query) {
    final needle = _normalize(query);
    if (needle.isEmpty) {
      return all;
    }
    return [
      for (final reciter in all)
        if (_normalize(reciter.label).contains(needle)) reciter,
    ];
  }

  static String _normalize(String input) {
    final buffer = StringBuffer();
    for (final rune in input.trim().toLowerCase().runes) {
      if (rune >= 0x064B && rune <= 0x0652) {
        continue;
      }
      buffer.writeCharCode(switch (rune) {
        0x0623 || 0x0625 || 0x0622 || 0x0671 => 0x0627,
        0x0649 => 0x064A,
        0x0629 => 0x0647,
        _ => rune,
      });
    }
    return buffer.toString();
  }
}
