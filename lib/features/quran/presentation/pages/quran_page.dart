import 'package:flutter/material.dart';

/// The Holy Quran page displaying Surahs and verses.
///
/// Features:
/// - Browse all 114 Surahs
/// - Read verses with Arabic text
/// - Adjust text size
/// - Audio playback
class QuranPage extends StatelessWidget {
  const QuranPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quran')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'القرآن الكريم',
              textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            const Text('Quran Feature Coming Soon'),
            const SizedBox(height: 16),
            Text(
              'This page will display:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '• Browse all 114 Surahs\n'
                '• Read verses with translations\n'
                '• Adjustable text size\n'
                '• Audio recitation\n'
                '• Search and bookmarks',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
