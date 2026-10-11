import 'haramain_week.dart';

/// One imam who leads prayers at a Haramain mosque.
class RosterImam {
  const RosterImam({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.mosque,
  });

  final String id;

  /// Canonical Arabic spelling, without titles.
  final String nameAr;
  final String nameEn;
  final HaramainMosque mosque;
}

/// The imams who appear in the weekly announcements.
///
/// Arabic spellings were checked against twelve real announcements from
/// Rabi' I to Rabi' II 1448 (the names that appear there are the ones the
/// parser tests use). NOT seen in any of those twelve weeks, so unverified
/// against the source: Saleh bin Humaid's and Ahmad Talib Hamid's current
/// duty status, and every English transliteration below, which is written from
/// memory and should be read by someone who knows the usual forms.
/// «علي الحذيفي» (the senior Sheikh Ali) and «أحمد بن علي الحذيفي» (his son)
/// are separate people and both appear in the announcements, so both are here.
///
/// A name that is missing from this list is not an error: the parser keeps the
/// source's own spelling. The list only buys a consistent spelling and an
/// English name.
const List<RosterImam> haramainRoster = [
  // Al-Masjid al-Haram.
  RosterImam(
    id: 'haram_sudais',
    nameAr: 'عبدالرحمن السديس',
    nameEn: 'Abdulrahman As-Sudais',
    mosque: HaramainMosque.haram,
  ),
  RosterImam(
    id: 'haram_muaiqly',
    nameAr: 'ماهر المعيقلي',
    nameEn: 'Maher Al-Muaiqly',
    mosque: HaramainMosque.haram,
  ),
  RosterImam(
    id: 'haram_humaid',
    nameAr: 'صالح بن حميد',
    nameEn: 'Saleh bin Humaid',
    mosque: HaramainMosque.haram,
  ),
  RosterImam(
    id: 'haram_khayyat',
    nameAr: 'أسامة خياط',
    nameEn: 'Usama Khayyat',
    mosque: HaramainMosque.haram,
  ),
  RosterImam(
    id: 'haram_juhany',
    nameAr: 'عبدالله الجهني',
    nameEn: 'Abdullah Al-Juhany',
    mosque: HaramainMosque.haram,
  ),
  RosterImam(
    id: 'haram_dossari',
    nameAr: 'ياسر الدوسري',
    nameEn: 'Yasser Ad-Dossari',
    mosque: HaramainMosque.haram,
  ),
  RosterImam(
    id: 'haram_baleelah',
    nameAr: 'بندر بليلة',
    nameEn: 'Bandar Baleelah',
    mosque: HaramainMosque.haram,
  ),
  RosterImam(
    id: 'haram_shamsan',
    nameAr: 'الوليد الشمسان',
    nameEn: 'Al-Waleed Ash-Shamsan',
    mosque: HaramainMosque.haram,
  ),
  RosterImam(
    id: 'haram_turki',
    nameAr: 'بدر التركي',
    nameEn: 'Badr At-Turki',
    mosque: HaramainMosque.haram,
  ),
  RosterImam(
    id: 'haram_ghazzawi',
    nameAr: 'فيصل غزاوي',
    nameEn: 'Faisal Ghazzawi',
    mosque: HaramainMosque.haram,
  ),
  // Al-Masjid an-Nabawi.
  RosterImam(
    id: 'nabawi_qasim',
    nameAr: 'عبدالمحسن القاسم',
    nameEn: 'Abdulmohsen Al-Qasim',
    mosque: HaramainMosque.nabawi,
  ),
  RosterImam(
    id: 'nabawi_budair',
    nameAr: 'صلاح البدير',
    nameEn: 'Salah Al-Budair',
    mosque: HaramainMosque.nabawi,
  ),
  RosterImam(
    id: 'nabawi_ahmad_hudhaify',
    nameAr: 'أحمد بن علي الحذيفي',
    nameEn: 'Ahmad bin Ali Al-Hudhaify',
    mosque: HaramainMosque.nabawi,
  ),
  RosterImam(
    id: 'nabawi_ali_hudhaify',
    nameAr: 'علي بن عبدالرحمن الحذيفي',
    nameEn: 'Ali bin Abdulrahman Al-Hudhaify',
    mosque: HaramainMosque.nabawi,
  ),
  RosterImam(
    id: 'nabawi_thubaity',
    nameAr: 'عبدالباري الثبيتي',
    nameEn: 'Abdulbari Ath-Thubaity',
    mosque: HaramainMosque.nabawi,
  ),
  RosterImam(
    id: 'nabawi_buaijan',
    nameAr: 'عبدالله البعيجان',
    nameEn: 'Abdullah Al-Buaijan',
    mosque: HaramainMosque.nabawi,
  ),
  RosterImam(
    id: 'nabawi_muhanna',
    nameAr: 'خالد المهنا',
    nameEn: 'Khalid Al-Muhanna',
    mosque: HaramainMosque.nabawi,
  ),
  RosterImam(
    id: 'nabawi_maghamsi',
    nameAr: 'صالح المغامسي',
    nameEn: 'Saleh Al-Maghamsi',
    mosque: HaramainMosque.nabawi,
  ),
  RosterImam(
    id: 'nabawi_talib_hamid',
    nameAr: 'أحمد طالب حميد',
    nameEn: 'Ahmad Talib Hamid',
    mosque: HaramainMosque.nabawi,
  ),
  RosterImam(
    id: 'nabawi_burhaji',
    nameAr: 'محمد البرهجي',
    nameEn: 'Muhammad Al-Burhaji',
    mosque: HaramainMosque.nabawi,
  ),
  RosterImam(
    id: 'nabawi_qarafi',
    nameAr: 'عبدالله القرافي',
    nameEn: 'Abdullah Al-Qarafi',
    mosque: HaramainMosque.nabawi,
  ),
  RosterImam(
    id: 'nabawi_aal_alsheikh',
    nameAr: 'حسين آل الشيخ',
    nameEn: 'Hussain Aal ash-Sheikh',
    mosque: HaramainMosque.nabawi,
  ),
];

/// The roster entry with this id, or null.
RosterImam? haramainImamById(String? id) {
  if (id == null) {
    return null;
  }
  for (final imam in haramainRoster) {
    if (imam.id == id) {
      return imam;
    }
  }
  return null;
}
