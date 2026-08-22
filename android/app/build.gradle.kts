import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Signing details, from android/key.properties or the matching environment
// variables. Absent on a fresh clone, which is fine for local debugging.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) {
        load(FileInputStream(file))
    }
}

fun signingValue(property: String, environment: String): String? =
    (keystoreProperties.getProperty(property) ?: System.getenv(environment))
        ?.takeIf { it.isNotBlank() }

val storeFilePath = signingValue("storeFile", "ANDROID_KEYSTORE_PATH")
val hasReleaseKey = storeFilePath != null && rootProject.file(storeFilePath).exists()

android {
    namespace = "com.islamicapp.islamic_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.islamicapp.islamic_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // CI passes a strictly increasing build number. Android compares this,
        // not versionName: reuse it and the installer treats a new APK as the
        // same app and quietly keeps the old one installed.
        versionCode = (System.getenv("ANDROID_VERSION_CODE")?.toIntOrNull())
            ?: flutter.versionCode
        versionName = System.getenv("ANDROID_VERSION_NAME") ?: flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = rootProject.file(storeFilePath!!)
                storePassword =
                    signingValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
                keyAlias = signingValue("keyAlias", "ANDROID_KEY_ALIAS")
                keyPassword = signingValue("keyPassword", "ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // With a real key every build upgrades the last one. Without it the
            // local debug key is used, which is fine on one machine but cannot
            // produce installable updates from CI — see android/key.properties.example.
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // Do not set ndk.abiFilters here. `flutter build apk --split-per-abi`
            // already limits the CPUs; Gradle refuses both at once.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required by flutter_local_notifications for Java 8+ APIs on older Android.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
