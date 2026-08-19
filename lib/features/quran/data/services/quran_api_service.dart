import 'package:dio/dio.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/secure_http_client.dart';
import '../../../../core/utils/app_logger.dart';

class QuranApiService {
  QuranApiService({Dio? dio})
      : _dio = dio ??
            SecureHttpClient.create(
              baseUrl: AppConstants.alQuranCloudApiBaseUrl,
            );

  final Dio _dio;

  Future<List<dynamic>> fetchSurahsList() async {
    try {
      final response = await _dio.get('/surah');
      if (response.statusCode == 200 && response.data != null) {
        return response.data['data'] as List<dynamic>;
      }
      return [];
    } catch (e, stack) {
      AppLogger.error('Failed to fetch surahs', e, stack);
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchSurah(int surahNumber) async {
    if (surahNumber < 1 || surahNumber > 114) {
      return null;
    }
    try {
      final response = await _dio.get('/surah/$surahNumber/quran-uthmani');
      if (response.statusCode == 200 && response.data != null) {
        return response.data['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e, stack) {
      AppLogger.error('Failed to fetch surah $surahNumber', e, stack);
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchJuz(int juzNumber) async {
    if (juzNumber < 1 || juzNumber > 30) {
      return null;
    }
    try {
      final response = await _dio.get('/juz/$juzNumber/quran-uthmani');
      if (response.statusCode == 200 && response.data != null) {
        return response.data['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e, stack) {
      AppLogger.error('Failed to fetch juz $juzNumber', e, stack);
      return null;
    }
  }

  Future<List<dynamic>> searchAyah(String keyword) async {
    final query = keyword.trim();
    if (query.isEmpty || query.length > 80) {
      return [];
    }
    if (query.contains('/') || query.contains('?') || query.contains('#')) {
      return [];
    }
    try {
      final encoded = Uri.encodeComponent(query);
      final response = await _dio.get('/search/$encoded/all/ar');
      if (response.statusCode == 200 && response.data != null) {
        return response.data['data']['matches'] as List<dynamic>;
      }
      return [];
    } catch (e, stack) {
      AppLogger.error('Failed to search ayahs', e, stack);
      return [];
    }
  }
}
