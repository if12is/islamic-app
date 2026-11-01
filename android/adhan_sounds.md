# Adhan audio

Bundled files live in `android/app/src/main/res/raw/`. Do not put markdown or
any other docs in that folder — Android treats every file there as a resource,
and resource names may only use lowercase `a-z`, `0-9`, and `_`.

`adhan_rifat.mp3` — أذان القاهرة، الشيخ محمد رفعت (islamweb.net)
`adhan_mustafa_ismail.mp3` — أذان الشيخ مصطفى إسماعيل (islamweb.net)
`adhan_fajr_abu_rahiq.mp3` — أذان الفجر، الشيخ إبراهيم جبر أبو رحيق (islamweb.net)
`adhan_nasraldeen_tobar.mp3` — أذان الشيخ نصر الدين طوبار، بلا «الصلاة خير من النوم» (soundcloud.com/egqurrec14/1xdig3wayjem)
`adhan_nasraldeen_tobar_fajr.mp3` — أذان الفجر، الشيخ نصر الدين طوبار، وفيه «الصلاة خير من النوم» (archive.org/details/KuranDosyalarm)

The first three were supplied by the app owner. Source metadata (ID3 tags)
credits islamweb.net. Those tags also carry a 2006 copyright notice. They are
not a licence to download further recordings from islamweb.net and ship them.

Nasr al-Din Tobar is bundled as well. The regular file is the public
SoundCloud track «آذان الشيخ نصر الدين طوبار» (soundcloud.com/egqurrec14/1xdig3wayjem).
The Fajr file is `NasreddinTubar.mp3` from the public Internet Archive item
Adhans (archive.org/details/KuranDosyalarm). The same bytes are copied into
`assets/audio/` so the in-app preview can play them. The Fajr recording
includes «الصلاة خير من النوم»; the regular one does not.

To add another adhan:

1. Drop the file in `android/app/src/main/res/raw/` with a lowercase, underscore-only name (`adhan_makkah.mp3`).
2. Add an `AdhanSound` entry in `NotificationService.adhanSounds` with that
   `rawResource` and a `nameKey`, and add the localized name in
   `app_localizations.dart`.

Android freezes a notification channel's sound at creation time, which is why
every sound gets its own channel (`adhanChannelFor`). Users can also import any
audio file at runtime from the notification centre — that path copies the file
into MediaStore and uses a `content://` URI instead of a raw resource.
