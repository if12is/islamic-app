import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/secure_http_client.dart';

final dailyAyahProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = SecureHttpClient.create(
    baseUrl: AppConstants.alQuranCloudApiBaseUrl,
  );
  final now = DateTime.now();
  final startOfYear = DateTime(now.year, 1, 1);
  final dayOfYear = now.difference(startOfYear).inDays;
  final ayahNumber = (dayOfYear % 6236) + 1;
  final response = await dio.get('/ayah/$ayahNumber/quran-uthmani');
  return Map<String, dynamic>.from(response.data['data'] as Map);
});
