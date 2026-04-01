import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dailyAyahProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = Dio();
  final now = DateTime.now();
  final startOfYear = DateTime(now.year, 1, 1);
  final dayOfYear = now.difference(startOfYear).inDays;
  final randomNumber = (dayOfYear % 6236) + 1;
  final response = await dio.get('https://api.alquran.cloud/v1/ayah/$randomNumber/quran-uthmani');
  return response.data['data'];
});
