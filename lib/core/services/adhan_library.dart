import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/adhan_sound.dart';
import '../utils/app_logger.dart';
import 'secure_http_client.dart';

/// Where an adhan comes from, for grouping the list.
enum AdhanRegion {
  haramain,
  egypt,
  levant,
  gulf,
  maghreb,
  turkey,
  asia,
  africa,
}

/// One voice in the adhan library.
class AdhanVoice {
  const AdhanVoice({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.placeAr,
    required this.placeEn,
    required this.region,
    required this.url,
    required this.bytes,
    this.fajr = false,
    this.rare = false,
  });

  /// Stable across releases: the installed sound is remembered under it.
  final String id;
  final String nameAr;
  final String nameEn;
  final String placeAr;
  final String placeEn;
  final AdhanRegion region;
  final String url;

  /// Size of the file, so the list can say how much a download costs.
  final int bytes;

  /// With «الصلاة خير من النوم», for Fajr only.
  final bool fajr;

  /// A recording from before 1985, or otherwise hard to find.
  final bool rare;

  String name(String languageCode) => languageCode == 'ar' ? nameAr : nameEn;
  String place(String languageCode) => languageCode == 'ar' ? placeAr : placeEn;
}

/// Adhans from around the Muslim world, downloaded when chosen.
///
/// Not bundled. The three adhans inside the app were supplied by its owner;
/// these are public recordings on the Internet Archive with no licence
/// stated, so the app fetches the one a listener picks, the way it already
/// streams the rare recitations, rather than shipping forty megabytes of
/// other people's recordings inside every install.
///
/// Every address was requested and answered with audio before it was
/// written here.
class AdhanLibrary {
  AdhanLibrary._();

  static const MethodChannel _channel = MethodChannel(
    'islamic_app/adhan_sound',
  );

  static const String _installedPrefix = 'adhan_library_v1:';

  static const String _ia = 'https://archive.org/download/';
  static const String _set = '${_ia}adhan-mp3-collection/';

  static const List<AdhanVoice> voices = [
    // --------------------------------------------------------- the Haramain
    AdhanVoice(
      id: 'mulla_makkah',
      nameAr: 'علي أحمد ملا',
      nameEn: 'Ali Ahmed Mulla',
      placeAr: 'المسجد الحرام، مكة',
      placeEn: 'al-Masjid al-Haram, Makkah',
      region: AdhanRegion.haramain,
      url: '${_ia}athan__201409/athan_ali_mulla.25-9-2014mp3.mp3',
      bytes: 949104,
    ),
    AdhanVoice(
      id: 'mulla_makkah_fajr',
      nameAr: 'علي أحمد ملا',
      nameEn: 'Ali Ahmed Mulla',
      placeAr: 'المسجد الحرام، مكة',
      placeEn: 'al-Masjid al-Haram, Makkah',
      region: AdhanRegion.haramain,
      url: '${_ia}athan_28-11-2014/athan_28-11-2014_ali_mulla_f.mp3',
      bytes: 3483923,
      fajr: true,
    ),
    AdhanVoice(
      id: 'makkah_fajr',
      nameAr: 'أذان الفجر من الحرم المكي',
      nameEn: 'Fajr from the Haram, Makkah',
      placeAr: 'المسجد الحرام، مكة',
      placeEn: 'al-Masjid al-Haram, Makkah',
      region: AdhanRegion.haramain,
      url: '${_set}adhan-fajr-al-haram-al-maki.mp3',
      bytes: 445824,
      fajr: true,
    ),
    AdhanVoice(
      id: 'madinah',
      nameAr: 'أذان المسجد النبوي',
      nameEn: 'The Prophet’s Mosque',
      placeAr: 'المسجد النبوي، المدينة',
      placeEn: 'al-Masjid an-Nabawi, Madinah',
      region: AdhanRegion.haramain,
      url: '${_ia}azan-madinah/AZAN%20MADINAH%20-%20%20%20.mp3',
      bytes: 2467917,
    ),
    AdhanVoice(
      id: 'madinah_fajr',
      nameAr: 'أذان الفجر من المسجد النبوي',
      nameEn: 'Fajr from the Prophet’s Mosque',
      placeAr: 'المسجد النبوي، المدينة',
      placeEn: 'al-Masjid an-Nabawi, Madinah',
      region: AdhanRegion.haramain,
      url: '${_set}adhan-fajr-al-haram-al-madani.mp3',
      bytes: 557568,
      fajr: true,
    ),
    AdhanVoice(
      id: 'bukhari_fajr_1403',
      nameAr: 'عصام بخاري — فجر ١٤٠٣هـ',
      nameEn: 'Essam Bukhari — Fajr, 1983',
      placeAr: 'المسجد النبوي، المدينة',
      placeEn: 'al-Masjid an-Nabawi, Madinah',
      region: AdhanRegion.haramain,
      url: '${_ia}adhan-past/AZHAN_M1.mp3',
      bytes: 943455,
      fajr: true,
      rare: true,
    ),

    // ---------------------------------------------------------------- Egypt
    AdhanVoice(
      id: 'naqshabandi',
      nameAr: 'سيد النقشبندي',
      nameEn: 'Sayyid al-Naqshabandi',
      placeAr: 'مصر',
      placeEn: 'Egypt',
      region: AdhanRegion.egypt,
      url: '${_set}sheikh-al-naqshbandi.mp3',
      bytes: 2188015,
      rare: true,
    ),
    AdhanVoice(
      id: 'hussary',
      nameAr: 'محمود خليل الحصري',
      nameEn: 'Mahmoud Khalil al-Hussary',
      placeAr: 'القاهرة',
      placeEn: 'Cairo',
      region: AdhanRegion.egypt,
      url: '${_set}mahmoud-khalil-al-hussary-cairo.mp3',
      bytes: 254880,
      rare: true,
    ),
    AdhanVoice(
      id: 'minshawi',
      nameAr: 'محمد صديق المنشاوي',
      nameEn: 'Muhammad Siddiq al-Minshawi',
      placeAr: 'مصر',
      placeEn: 'Egypt',
      region: AdhanRegion.egypt,
      url: '${_ia}azan-salawat-menchawi-shsamirmostafa.com/azan-menchawi.mp3',
      bytes: 3329599,
      rare: true,
    ),
    AdhanVoice(
      id: 'abdulbasit_fajr',
      nameAr: 'عبد الباسط عبد الصمد',
      nameEn: 'Abdul Basit Abdus Samad',
      placeAr: 'مصر',
      placeEn: 'Egypt',
      region: AdhanRegion.egypt,
      url: '${_set}abdulbasit-abdusamad-7-fajr-egypt.mp3',
      bytes: 3091644,
      fajr: true,
      rare: true,
    ),
    AdhanVoice(
      id: 'banna',
      nameAr: 'محمود علي البنا',
      nameEn: 'Mahmoud Ali al-Banna',
      placeAr: 'القاهرة',
      placeEn: 'Cairo',
      region: AdhanRegion.egypt,
      url: '${_set}mahmoud-ali-al-banna-cairo.mp3',
      bytes: 331920,
      rare: true,
    ),
    AdhanVoice(
      id: 'raghib_ghaloush',
      nameAr: 'راغب مصطفى غلوش',
      nameEn: 'Raghib Mustafa Ghaloush',
      placeAr: 'مصر',
      placeEn: 'Egypt',
      region: AdhanRegion.egypt,
      url: '${_ia}azan.raghib/azan.raghib.mp3',
      bytes: 772085,
    ),

    // ----------------------------------------------------------------- Gulf
    AdhanVoice(
      id: 'alafasy',
      nameAr: 'مشاري راشد العفاسي',
      nameEn: 'Mishary Rashid Alafasy',
      placeAr: 'الكويت',
      placeEn: 'Kuwait',
      region: AdhanRegion.gulf,
      url: '${_set}mishary-rashid-alafasy-hq.mp3',
      bytes: 617743,
    ),
    AdhanVoice(
      id: 'alafasy_fajr',
      nameAr: 'مشاري راشد العفاسي',
      nameEn: 'Mishary Rashid Alafasy',
      placeAr: 'الكويت',
      placeEn: 'Kuwait',
      region: AdhanRegion.gulf,
      url:
          '${_ia}AthanAl-fajirMuhammediezanMisharyRashedAlafasy/'
          'AthanAl-fajirMuhammediezanMisharyRashedAlafasy.mp3',
      bytes: 4458785,
      fajr: true,
    ),
    AdhanVoice(
      id: 'qatami',
      nameAr: 'ناصر القطامي',
      nameEn: 'Nasser al-Qatami',
      placeAr: 'الرياض',
      placeEn: 'Riyadh',
      region: AdhanRegion.gulf,
      url: '${_set}nasser-al-qatami-hq.mp3',
      bytes: 526524,
    ),
    AdhanVoice(
      id: 'yamani',
      nameAr: 'وادي حمد اليماني',
      nameEn: 'Wadi Hamad al-Yamani',
      placeAr: 'اليمن',
      placeEn: 'Yemen',
      region: AdhanRegion.gulf,
      url: '${_set}wadi-hamad-al-yamani.mp3',
      bytes: 3201985,
    ),

    // --------------------------------------------------------------- Levant
    AdhanVoice(
      id: 'aqsa_qazaz',
      nameAr: 'ناجي القزاز',
      nameEn: 'Naji al-Qazzaz',
      placeAr: 'المسجد الأقصى، القدس',
      placeEn: 'al-Aqsa, Jerusalem',
      region: AdhanRegion.levant,
      url: '${_set}najee-qazaz-al-aqsa-jerusalem.mp3',
      bytes: 452736,
    ),
    AdhanVoice(
      id: 'damascus',
      nameAr: 'الأذان الشامي',
      nameEn: 'Damascene adhan',
      placeAr: 'دمشق',
      placeEn: 'Damascus',
      region: AdhanRegion.levant,
      url: '${_set}adhan-syria.mp3',
      bytes: 442656,
    ),

    // -------------------------------------------------------------- Maghreb
    AdhanVoice(
      id: 'kazabri',
      nameAr: 'عمر القزابري',
      nameEn: 'Omar al-Kazabri',
      placeAr: 'الدار البيضاء، المغرب',
      placeEn: 'Casablanca, Morocco',
      region: AdhanRegion.maghreb,
      url: '${_set}omar-al-kazabri.mp3',
      bytes: 1896906,
    ),
    AdhanVoice(
      id: 'blida',
      nameAr: 'أذان البليدة',
      nameEn: 'Blida adhan',
      placeAr: 'البليدة، الجزائر',
      placeEn: 'Blida, Algeria',
      region: AdhanRegion.maghreb,
      url:
          '${_ia}nhichem_gmail_20190620/'
          '%D8%A3%D8%B0%D8%A7%D9%86_%D8%A7%D9%84%D8%A8%D9%84%D9%8A%D8%AF%D8%A9.mp3',
      bytes: 2361096,
    ),
    AdhanVoice(
      id: 'tunisia',
      nameAr: 'الأذان التونسي',
      nameEn: 'Tunisian adhan',
      placeAr: 'تونس',
      placeEn: 'Tunisia',
      region: AdhanRegion.maghreb,
      url: '${_set}adhan-tunisia.mp3',
      bytes: 287784,
    ),

    // --------------------------------------------------------------- Turkey
    AdhanVoice(
      id: 'gunesdogdu',
      nameAr: 'مصطفى أوزجان كونش دوغدو',
      nameEn: 'Mustafa Özcan Güneşdoğdu',
      placeAr: 'إسطنبول',
      placeEn: 'Istanbul',
      region: AdhanRegion.turkey,
      url: '${_ia}m-ozcan-gunesdogdu/4-ikindi-Ezani_64kb.mp3',
      bytes: 1660000,
    ),
    AdhanVoice(
      id: 'gunesdogdu_fajr',
      nameAr: 'مصطفى أوزجان كونش دوغدو',
      nameEn: 'Mustafa Özcan Güneşdoğdu',
      placeAr: 'إسطنبول',
      placeEn: 'Istanbul',
      region: AdhanRegion.turkey,
      url: '${_ia}m-ozcan-gunesdogdu/2-Sabah-ezani_64kb.mp3',
      bytes: 2245275,
      fajr: true,
    ),

    // ----------------------------------------------------------------- Asia
    AdhanVoice(
      id: 'indonesia',
      nameAr: 'الأذان الإندونيسي',
      nameEn: 'Indonesian adhan',
      placeAr: 'إندونيسيا',
      placeEn: 'Indonesia',
      region: AdhanRegion.asia,
      url: '${_set}adhan-indonesia.mp3',
      bytes: 395136,
    ),
    AdhanVoice(
      id: 'malaysia',
      nameAr: 'الأذان الماليزي',
      nameEn: 'Malaysian adhan',
      placeAr: 'ماليزيا',
      placeEn: 'Malaysia',
      region: AdhanRegion.asia,
      url: '${_set}adhan-malaysia-1.mp3',
      bytes: 396360,
    ),
    AdhanVoice(
      id: 'pakistan',
      nameAr: 'الأذان الباكستاني',
      nameEn: 'Pakistani adhan',
      placeAr: 'باكستان',
      placeEn: 'Pakistan',
      region: AdhanRegion.asia,
      url: '${_set}adhan-pakistan.mp3',
      bytes: 365256,
    ),

    // --------------------------------------------------------------- Africa
    AdhanVoice(
      id: 'kenya',
      nameAr: 'أذان من شرق أفريقيا',
      nameEn: 'East African adhan',
      placeAr: 'كينيا',
      placeEn: 'Kenya',
      region: AdhanRegion.africa,
      url: '${_set}adhan-kenya.mp3',
      bytes: 3357363,
    ),
  ];

  static AdhanVoice? byId(String id) {
    for (final voice in voices) {
      if (voice.id == id) {
        return voice;
      }
    }
    return null;
  }

  /// The voice an installed sound came from, if it came from here.
  static AdhanVoice? voiceFor(AdhanSoundSelection selection) {
    final uri = selection.uri;
    if (uri == null) {
      return null;
    }
    for (final voice in voices) {
      if (_installed[voice.id] == uri) {
        return voice;
      }
    }
    return null;
  }

  static final Map<String, String> _installed = {};

  /// Load which voices are already on this phone.
  static Future<void> load([SharedPreferences? preferences]) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    for (final voice in voices) {
      final uri = prefs.getString('$_installedPrefix${voice.id}');
      if (uri != null && uri.isNotEmpty) {
        _installed[voice.id] = uri;
      }
    }
  }

  static bool isInstalled(AdhanVoice voice) => _installed.containsKey(voice.id);

  /// Fetch [voice] and make it a sound the adhan channel can play.
  ///
  /// Downloaded once; choosing it again reuses the copy already installed.
  /// Throws [AdhanLibraryException] with a reason the screen can show.
  static Future<AdhanSoundSelection> install(AdhanVoice voice) async {
    final existing = _installed[voice.id];
    if (existing != null) {
      return AdhanSoundSelection(
        id: AdhanSoundSelection.customId,
        uri: existing,
        title: voice.nameAr,
      );
    }
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw const AdhanLibraryException('unsupported');
    }

    final List<int> bytes;
    try {
      bytes = await SecureHttpClient.getBytes(voice.url);
    } catch (e) {
      AppLogger.warning('Adhan download failed for ${voice.id}: $e');
      throw const AdhanLibraryException('network');
    }
    if (bytes.length < 16 * 1024) {
      // An error page, not an adhan.
      throw const AdhanLibraryException('network');
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/adhan_${voice.id}.mp3');
    await file.writeAsBytes(bytes, flush: true);

    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'installSound',
        {'path': file.path, 'name': 'أذان ${voice.nameAr}'},
      );
      final uri = result?['uri'] as String?;
      if (uri == null || uri.isEmpty) {
        throw const AdhanLibraryException('install');
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_installedPrefix${voice.id}', uri);
      _installed[voice.id] = uri;
      return AdhanSoundSelection(
        id: AdhanSoundSelection.customId,
        uri: uri,
        title: voice.nameAr,
      );
    } on PlatformException catch (e) {
      AppLogger.warning('Adhan install failed for ${voice.id}: ${e.code}');
      throw AdhanLibraryException(
        e.code == 'unsupported' ? 'unsupported' : 'install',
      );
    } finally {
      try {
        await file.delete();
      } catch (_) {
        // The temporary folder is the system's to clear anyway.
      }
    }
  }

  /// For tests.
  @visibleForTesting
  static void resetForTest() => _installed.clear();
}

/// Why a voice could not be added: `network`, `install` or `unsupported`.
class AdhanLibraryException implements Exception {
  const AdhanLibraryException(this.reason);

  final String reason;

  @override
  String toString() => 'AdhanLibraryException($reason)';
}
