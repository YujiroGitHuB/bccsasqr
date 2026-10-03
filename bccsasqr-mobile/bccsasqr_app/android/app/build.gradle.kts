plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.bccsasqr_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.bccsasqr_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // The APK is downloaded from the website over students' mobile data, not
    // from Play, which would compress the download itself. Compressed, the
    // native libraries are about half their size; the phone unpacks only its
    // own CPU's on install, so it takes no more room installed. Every Android
    // version installs it this way — it was the default until AGP 3.6.
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")

            // ARM only: every phone is armeabi-v7a (old, cheap, Android Go)
            // or arm64-v8a. x86_64 is for emulators and Intel Chromebooks, and
            // was a third of the APK (22 of 64 MB). Cleared first: the Flutter
            // plugin has already put all three here by the time this runs.
            // Debug builds keep x86_64, so the emulator still works.
            ndk {
                abiFilters.clear()
                abiFilters.addAll(listOf("armeabi-v7a", "arm64-v8a"))
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // The AppCompat themes in res/values*/styles.xml, which the fingerprint
    // prompt needs on Android 8 and older.
    implementation("androidx.appcompat:appcompat:1.7.0")
}
