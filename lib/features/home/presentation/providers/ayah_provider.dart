import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/secure_http_client.dart';
import '../../../../core/utils/app_logger.dart';

const int _quranAyahCount = 6236;

int _ayahNumberForToday() {
  final now = DateTime.now();
  final startOfYear = DateTime(now.year, 1, 1);
  final dayOfYear = now.difference(startOfYear).inDays;
  return (dayOfYear % _quranAyahCount) + 1;
}

class DailyAyahIndexNotifier extends Notifier<int> {
  @override
  int build() => _ayahNumberForToday();

  void shuffle() {
    final random = Random();
    var next = random.nextInt(_quranAyahCount) + 1;
    while (next == state) {
      next = random.nextInt(_quranAyahCount) + 1;
    }
    state = next;
    AppLogger.info('Shuffled ayah to $next');
  }
}

final dailyAyahIndexProvider =
    NotifierProvider<DailyAyahIndexNotifier, int>(DailyAyahIndexNotifier.new);

final dailyAyahProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final ayahNumber = ref.watch(dailyAyahIndexProvider);
  final dio = SecureHttpClient.create(
    baseUrl: AppConstants.alQuranCloudApiBaseUrl,
  );
  final response = await dio.get('/ayah/$ayahNumber/quran-uthmani');
  return Map<String, dynamic>.from(response.data['data'] as Map);
});
