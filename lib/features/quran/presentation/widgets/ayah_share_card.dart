import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/app_logger.dart';
import '../../data/services/quran_local_service.dart';
import '../providers/reader_settings_provider.dart';

/// Background styles for a shared verse card.
enum AyahCardStyle { emerald, night, parchment }

/// Renders a verse as a shareable image.
///
/// The card is composed off-screen and handed straight to the platform share
/// sheet, so sharing a verse never leaves a stray file behind in the gallery.
class AyahShareCard extends StatelessWidget {
  const AyahShareCard({
    super.key,
    required this.verse,
    required this.style,
    this.fontFamily = 'AmiriQuran',
  });

  final QuranVerse verse;
  final AyahCardStyle style;
  final String fontFamily;

  static const double cardSize = 1080;

  @override
  Widget build(BuildContext context) {
    final theme = _theme(style);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: cardSize,
        height: cardSize,
        decoration: BoxDecoration(gradient: theme.gradient),
        padding: const EdgeInsets.all(88),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: theme.accent, width: 2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'سورة ${verse.surahNameAr}',
                style: TextStyle(
                  fontFamily: 'ReemKufi',
                  fontSize: 40,
                  color: theme.accent,
                ),
              ),
            ),
            const Spacer(),
            Text(
              verse.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: _fontSizeFor(verse.text),
                height: 2.0,
                color: theme.text,
              ),
            ),
            const SizedBox(height: 48),
            Text(
              '﴿ ${_arabicNumber(verse.numberInSurah)} ﴾',
              style: TextStyle(
                fontFamily: 'AmiriQuran',
                fontSize: 44,
                color: theme.accent,
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mosque, color: theme.muted, size: 32),
                const SizedBox(width: 12),
                Text(
                  'الفجر · تطبيق إسلامي',
                  style: TextStyle(
                    fontFamily: 'ReemKufi',
                    fontSize: 30,
                    color: theme.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Long verses need smaller type to stay on one card.
  static double _fontSizeFor(String text) {
    if (text.length > 600) {
      return 40;
    }
    if (text.length > 320) {
      return 52;
    }
    if (text.length > 150) {
      return 64;
    }
    return 78;
  }

  static String _arabicNumber(int value) {
    const digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return value
        .toString()
        .split('')
        .map((char) => digits[int.parse(char)])
        .join();
  }

  static _CardTheme _theme(AyahCardStyle style) {
    switch (style) {
      case AyahCardStyle.emerald:
        return const _CardTheme(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF07231A), Color(0xFF0B6B4F)],
          ),
          text: Color(0xFFF3F8F5),
          accent: Color(0xFFE9C349),
          muted: Color(0xB3F3F8F5),
        );
      case AyahCardStyle.night:
        return const _CardTheme(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B0F14), Color(0xFF1B2430)],
          ),
          text: Color(0xFFEDF1F5),
          accent: Color(0xFF7FD8B6),
          muted: Color(0xB3EDF1F5),
        );
      case AyahCardStyle.parchment:
        return const _CardTheme(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFFF6ECD8), Color(0xFFE6D2AE)],
          ),
          text: Color(0xFF3E3016),
          accent: Color(0xFF8A5A17),
          muted: Color(0xB33E3016),
        );
    }
  }
}

class _CardTheme {
  const _CardTheme({
    required this.gradient,
    required this.text,
    required this.accent,
    required this.muted,
  });

  final LinearGradient gradient;
  final Color text;
  final Color accent;
  final Color muted;
}

/// Builds the image and opens the share sheet.
class AyahSharing {
  AyahSharing._();

  /// Share the verse as plain text.
  static Future<void> shareText(QuranVerse verse) async {
    final text =
        '${verse.text}\n\n﴿ سورة ${verse.surahNameAr} — الآية '
        '${verse.numberInSurah} ﴾';
    await SharePlus.instance.share(ShareParams(text: text));
  }

  /// Render the verse card and share it as a PNG.
  static Future<bool> shareImage({
    required QuranVerse verse,
    required AyahCardStyle style,
    ReaderFont font = ReaderFont.amiriQuran,
    Size? targetSize,
  }) async {
    try {
      final controller = ScreenshotController();
      final bytes = await controller.captureFromWidget(
        AyahShareCard(verse: verse, style: style, fontFamily: font.family),
        delay: const Duration(milliseconds: 120),
        targetSize:
            targetSize ??
            const Size(AyahShareCard.cardSize, AyahShareCard.cardSize),
        pixelRatio: 1,
      );

      await _shareBytes(bytes, verse);
      return true;
    } catch (e, stack) {
      AppLogger.error('Failed to share verse image', e, stack);
      return false;
    }
  }

  static Future<void> _shareBytes(Uint8List bytes, QuranVerse verse) async {
    final fileName = 'ayah_${verse.surahNumber}_${verse.numberInSurah}.png';
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'image/png', name: fileName)],
        fileNameOverrides: [fileName],
      ),
    );
  }
}
