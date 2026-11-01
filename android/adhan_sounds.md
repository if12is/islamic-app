# Adhan audio

Bundled files live in `android/app/src/main/res/raw/`. Do not put markdown or
any other docs in that folder — Android treats every file there as a resource,
and resource names may only use lowercase `a-z`, `0-9`, and `_`.

`adhan_rifat.mp3` — أذان القاهرة، الشيخ محمد رفعت (islamweb.net)
`adhan_mustafa_ismail.mp3` — أذان الشيخ مصطفى إسماعيل (islamweb.net)
`adhan_fajr_abu_rahiq.mp3` — أذان الفجر، الشيخ إبراهيم جبر أبو رحيق (islamweb.net)

Supplied by the app owner. Source metadata (ID3 tags) credits islamweb.net.
Those tags also carry a 2006 copyright notice. They are not a licence to
download further recordings from islamweb.net and ship them.

## Nasr al-Din Tobar — not bundled

Two sounds were requested, on the same pattern as the files above:

- id `nasraldeen_tobar`, raw `adhan_nasraldeen_tobar` — the adhan without
  «الصلاة خير من النوم»
- id `nasraldeen_tobar_fajr`, raw `adhan_nasraldeen_tobar_fajr` — Fajr, with
  that phrase

They are not in `NotificationService.adhanSounds`. Copies in circulation
(islamweb, SoundCloud, video rips, unlicensed archive uploads) do not state
a licence that allows redistributing them inside the app, and this repo has
no script that fetches them. Listing the ids without the files fails the
preview test and would offer a sound the notification channel cannot play.
The localized names `adhan_sound_nasraldeen_tobar` and
`adhan_sound_nasraldeen_tobar_fajr` are already in both languages. When the
owner supplies the two mp3s, drop each file in `res/raw/` and `assets/audio/`,
then add the `AdhanSound` entries and the matching preview paths.

To add another adhan:

1. Drop the file in `android/app/src/main/res/raw/` with a lowercase, underscore-only name (`adhan_makkah.mp3`).
2. Add an `AdhanSound` entry in `NotificationService.adhanSounds` with that
   `rawResource` and a `nameKey`, and add the localized name in
   `app_localizations.dart`.

Android freezes a notification channel's sound at creation time, which is why
every sound gets its own channel (`adhanChannelFor`). Users can also import any
audio file at runtime from the notification centre — that path copies the file
into MediaStore and uses a `content://` URI instead of a raw resource.
