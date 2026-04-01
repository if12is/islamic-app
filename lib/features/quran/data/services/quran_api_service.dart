import 'package:dio/dio.dart';

class QuranApiService {
  final Dio _dio = Dio();

  /// Fetches the list of all Surahs (Metadata only, no texts)
  Future<List<dynamic>> fetchSurahsList() async {
    try {
      final response = await _dio.get('https://api.alquran.cloud/v1/surah');
      if (response.statusCode == 200 && response.data != null) {
        return response.data['data'] as List<dynamic>;
      }
      return [];
    } catch (e) {
      print('Error fetching surahs: $e');
      return [];
    }
  }

  /// Fetches full data for a specific Surah (including text of ayahs)
  /// Using 'quran-uthmani' edition for beautiful arabic script
  Future<Map<String, dynamic>?> fetchSurah(int surahNumber) async {
    try {
      final response = await _dio.get('https://api.alquran.cloud/v1/surah/$surahNumber/quran-uthmani');
      if (response.statusCode == 200 && response.data != null) {
        return response.data['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error fetching surah texts: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchJuz(int juzNumber) async {
    try {
      final response = await _dio.get('https://api.alquran.cloud/v1/juz/$juzNumber/quran-uthmani');
      if (response.statusCode == 200 && response.data != null) {
        return response.data['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error fetching juz texts: $e');
      return null;
    }
  }

  /// Searches for Ayahs containing a specific keyword
  Future<List<dynamic>> searchAyah(String keyword) async {
    try {
      // Searching in Arabic text (edition: quran-simple for better searchability or 'all')
      final response = await _dio.get('https://api.alquran.cloud/v1/search/$keyword/all/ar');
      if (response.statusCode == 200 && response.data != null) {
        return response.data['data']['matches'] as List<dynamic>;
      }
      return [];
    } catch (e) {
      print('Error searching ayahs: $e');
      return [];
    }
  }
}
