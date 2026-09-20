/// The readings of the Qur'an, and the two facts about them the app cannot
/// guess.
///
/// A riwayah is not a style of voice. It is a different transmitted reading:
/// a different rasm on the page, and — the part that quietly breaks players —
/// a different way of **counting verses**. Hafs counts al-Baqarah at 286 and
/// al-Tawbah at 129; Warsh counts them at 285 and 130. Nothing in a file name
/// says which of those two a recording followed, and a URL built from the
/// wrong one does not fail. It plays the wrong ayah, all the way down the
/// surah, and only someone who knows the text hears it.
library;

/// How a corpus numbers its verses.
///
/// Recorded per recitation rather than per riwayah, because the two do not
/// follow each other: of the three Warsh recordings on the per-ayah host, two
/// are filed under Hafs numbering and one under Warsh. This was measured, not
/// assumed — al-Baqarah 286 and al-Tawbah 130 exist in exactly one of the two
/// schemes each, so asking the host for both settles it.
enum VerseCounting {
  /// The Kufan count, 6236 verses. What Hafs uses, and what the per-ayah host
  /// files most of its corpus under whatever the reading is.
  hafs,

  /// The last Madani count, 6214 verses.
  ///
  /// What the Warsh **and** Qalun mushafs print — both readings come through
  /// Nafi` of Madina and both were checked against the provider, which labels
  /// each of them `المدني الأخير`. Al-Baqarah ends at 285 and al-Tawbah at 130
  /// in both, so one scheme covers the pair and a third enum value would only
  /// be two names for the same numbers.
  madaniAkhir,
}

/// A transmitted reading, as the audio provider names it.
///
/// The list comes from mp3quran's `/riwayat` endpoint rather than being
/// written down here, because the app should offer whatever the provider
/// carries — Qalun, al-Duri, al-Bazzi and the rest — not a subset someone
/// chose once. Only [MushafEdition] is a closed set, and for the narrower
/// reason that it needs a text to show.
class Riwaya {
  const Riwaya({required this.id, required this.nameAr});

  /// mp3quran's `rewaya_id`. 1 is Hafs, 2 is Warsh.
  final int id;

  final String nameAr;

  /// Hafs `an` Asim, the reading most of the world reads and the app's default.
  static const int hafsId = 1;

  /// Warsh `an` Nafi`, by the main route.
  static const int warshId = 2;

  /// Warsh by the route of al-Asbahani — the same reading, a different tariq.
  ///
  /// Grouped with Warsh for the purpose of "may this play while I read Warsh",
  /// because it is Warsh; kept as its own id because it is not the same
  /// recording tradition and a reader who wants one may not want the other.
  static const int warshAsbahaniId = 10;

  /// Warsh by the route of al-Azraq — the route the printed Warsh mushaf
  /// follows, and the one a Maghrebi reader means by "ورش".
  ///
  /// Leaving it out of [isWarsh] hid two complete recitations from the very
  /// readers the Warsh edition was added for.
  static const int warshAzraqId = 18;

  /// Qalun `an` Nafi`, the reading of Libya and much of Tunisia.
  static const int qaloonId = 5;

  /// Qalun by the route of Abu Nashit, grouped with Qalun for the same reason
  /// al-Asbahani is grouped with Warsh: it is that reading.
  static const int qaloonAbiNashitId = 8;

  /// Whether [id] is any route of Warsh.
  static bool isWarsh(int id) =>
      id == warshId || id == warshAsbahaniId || id == warshAzraqId;

  /// Whether [id] is any route of Qalun.
  static bool isQaloon(int id) => id == qaloonId || id == qaloonAbiNashitId;

  /// The riwayat that ship, so a first launch with no network still groups
  /// recordings correctly instead of piling them under one unnamed heading.
  ///
  /// Copied from the provider's own `/riwayat` response rather than written
  /// from memory, ids and spellings included — a name invented here and a name
  /// fetched later are two tabs for one reading.
  static const List<Riwaya> bundled = [
    Riwaya(id: hafsId, nameAr: 'حفص عن عاصم'),
    Riwaya(id: warshId, nameAr: 'ورش عن نافع'),
    Riwaya(id: qaloonId, nameAr: 'قالون عن نافع'),
    Riwaya(id: 3, nameAr: 'خلف عن حمزة'),
    Riwaya(id: 4, nameAr: 'البزي عن ابن كثير'),
    Riwaya(id: 6, nameAr: 'قنبل عن ابن كثير'),
    Riwaya(id: 7, nameAr: 'السوسي عن أبي عمرو'),
    Riwaya(id: qaloonAbiNashitId, nameAr: 'قالون عن نافع من طريق أبي نشيط'),
    Riwaya(id: 9, nameAr: 'قراءة يعقوب الحضرمي بروايتي رويس وروح'),
    Riwaya(
      id: warshAsbahaniId,
      nameAr: 'ورش عن نافع من طريق أبي بكر الأصبهاني',
    ),
    Riwaya(id: 11, nameAr: 'البزي وقنبل عن ابن كثير'),
    Riwaya(id: 12, nameAr: 'الدوري عن الكسائي'),
    Riwaya(id: 13, nameAr: 'الدوري عن أبي عمرو'),
    Riwaya(id: 15, nameAr: 'شعبة عن عاصم'),
    Riwaya(id: 16, nameAr: 'ابن ذكوان عن ابن عامر'),
    Riwaya(id: warshAzraqId, nameAr: 'ورش عن نافع من طريق الأزرق'),
    Riwaya(id: 19, nameAr: 'هشام عن ابن عامر'),
    Riwaya(id: 20, nameAr: 'ابن جماز عن أبي جعفر'),
    Riwaya(id: 21, nameAr: 'المصحف المعلم'),
    Riwaya(id: 22, nameAr: 'المصحف المجود'),
  ];

  static String nameFor(int id, List<Riwaya> known) {
    for (final riwaya in known) {
      if (riwaya.id == id) {
        return riwaya.nameAr;
      }
    }
    return 'رواية أخرى';
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': nameAr};

  static Riwaya? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = (json['name'] as String? ?? '').trim();
    if (id is! num || name.isEmpty) {
      return null;
    }
    return Riwaya(id: id.toInt(), nameAr: name);
  }
}

/// A reading the app can actually *show*, not merely play.
///
/// Audio exists for a dozen riwayat; a text the reader can follow exists here
/// for the three whose mushaf is wired up. Offering a fourth in the reader
/// before its text is fetched would be the same failure this whole change is
/// about — a choice that looks live and silently does something else.
enum MushafEdition {
  hafs(
    riwayaId: Riwaya.hafsId,
    nameAr: 'حفص عن عاصم',
    shortAr: 'حفص',
    counting: VerseCounting.hafs,
  ),
  warsh(
    riwayaId: Riwaya.warshId,
    nameAr: 'ورش عن نافع',
    shortAr: 'ورش',
    counting: VerseCounting.madaniAkhir,
  ),
  qaloon(
    riwayaId: Riwaya.qaloonId,
    nameAr: 'قالون عن نافع',
    shortAr: 'قالون',
    counting: VerseCounting.madaniAkhir,
  );

  const MushafEdition({
    required this.riwayaId,
    required this.nameAr,
    required this.shortAr,
    required this.counting,
  });

  final int riwayaId;
  final String nameAr;

  /// One word, for a chip or a tab where the full name will not fit.
  final String shortAr;

  /// How this mushaf numbers its verses.
  final VerseCounting counting;

  /// Stored in preferences and backups, so the name survives a reordering.
  String get id => name;

  static MushafEdition fromId(String? id) => MushafEdition.values.firstWhere(
    (edition) => edition.id == id,
    orElse: () => MushafEdition.hafs,
  );

  /// Whether a recording in [riwayaId] belongs to this reading.
  ///
  /// The question the reader is really asking is "will this recite what is on
  /// my page", so every route of a reading counts: al-Azraq and al-Asbahani
  /// for Warsh, Abu Nashit for Qalun. The app's own text follows one route,
  /// but the differences between routes are of pronunciation, not of wording,
  /// and a reader who picked Warsh is not misled by hearing al-Azraq.
  bool accepts(int recordingRiwayaId) => switch (this) {
    MushafEdition.hafs => recordingRiwayaId == Riwaya.hafsId,
    MushafEdition.warsh => Riwaya.isWarsh(recordingRiwayaId),
    MushafEdition.qaloon => Riwaya.isQaloon(recordingRiwayaId),
  };
}
