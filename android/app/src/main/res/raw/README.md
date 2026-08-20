# Adhan audio

`adhan_rifat.mp3` — أذان القاهرة، الشيخ محمد رفعت (islamweb.net)
`adhan_mustafa_ismail.mp3` — أذان الشيخ مصطفى إسماعيل (islamweb.net)
`adhan_fajr_abu_rahiq.mp3` — أذان الفجر، الشيخ إبراهيم جبر أبو رحيق (islamweb.net)

Supplied by the app owner. Source metadata (ID3 tags) credits islamweb.net.

To add another adhan:

1. Drop the file here with a lowercase, underscore-only name (`adhan_makkah.mp3`).
2. Add an `AdhanSound` entry in `NotificationService.adhanSounds` with that
   `rawResource` and a `nameKey`, and add the localized name in
   `app_localizations.dart`.

Android freezes a notification channel's sound at creation time, which is why
every sound gets its own channel (`adhanChannelFor`). Users can also import any
audio file at runtime from the notification centre — that path copies the file
into MediaStore and uses a `content://` URI instead of a raw resource.
