# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# just_audio / audio_service / background playback
-keep class com.ryanheise.** { *; }
-dontwarn com.ryanheise.**

# Offline recitation (JNI)
-keep class com.k2fsa.sherpa.onnx.** { *; }
-keep class com.k2fsa.** { *; }
-dontwarn com.k2fsa.**

# In-app updates
-keep class sk.fourq.otaupdate.** { *; }
-dontwarn sk.fourq.otaupdate.**

# Home-screen prayer widget
-keep class com.islamicapp.islamic_app.** { *; }

# Flutter local notifications / desugar
-dontwarn java.lang.invoke.**
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
