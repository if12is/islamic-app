import 'package:flutter/material.dart';

/// Prayer Times page displaying the 5 daily prayers with times.
///
/// Features:
/// - List of all 5 prayers with their times
/// - Countdown to the next prayer
/// - Qibla compass
class PrayerTimesPage extends StatelessWidget {
  const PrayerTimesPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prayer Times')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'عوقات الصلوات',
              textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            const Text('Prayer Times Feature Coming Soon'),
            const SizedBox(height: 16),
            Text(
              'This page will display:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '• Daily prayer times (Fajr, Dhuhr, Asr, Maghrib, Isha)\n'
                '• Sunrise and sunset times\n'
                '• Countdown to next prayer\n'
                '• Qibla direction indicator\n'
                '• Prayer reminders and notifications',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
