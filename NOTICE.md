# Third-party material

The source code of Fajr (الفجر) is licensed under the [GNU GPL v3.0 or later](LICENSE).
The app also bundles material by others, which keeps its own license and is **not** relicensed by this repository:

| Material | Path | License |
| --- | --- | --- |
| Fonts: Amiri Quran, Cairo, Readex Pro, Reem Kufi, Scheherazade New | `assets/fonts/` | SIL Open Font License 1.1 (Readex Pro license text in `assets/fonts/ReadexPro-OFL.txt`) |
| Tabler icons | `assets/icons/` | MIT (`assets/icons/LICENSE.md`) |
| Adhan recordings | `assets/audio/` | Rights belong to the muezzins and the original recording owners. This repository claims no ownership of them and they are not covered by the GPL. If you hold rights to a recording and want it removed or credited differently, open an issue. |
| Optional speech models (downloaded on request) | — | Listed in `lib/features/quran/data/services/stt_model_catalogue.dart` with each model's license |
| Dart and Flutter packages | `pubspec.yaml` | Each package's own license (see pub.dev) |

The app uses `ffmpeg_kit_flutter_new_min_gpl`, a GPL build of FFmpeg, which is one reason the app as a whole is distributed under the GPL.
