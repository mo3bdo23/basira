plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.basira.app"
    compileSdk = flutter.compileSdkVersion
    // لا تُضبط نسخة NDK: كل الإضافات Java/Kotlin بلا كود أصلي،
    // وضبطها يجبر Gradle على تنزيل NDK بحجم ~1GB بلا داعٍ.

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.basira.app"
        // الحد الأدنى 23 لدعم flutter_secure_storage (Keystore) بشكل موثوق.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // ملاحظة: للتوقيع للإنتاج، أنشئ key.properties و signingConfigs.release.
            // نستخدم توقيع debug هنا حتى يعمل `flutter build apk --release` مباشرة.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        resources {
            excludes += setOf("META-INF/AL2.0", "META-INF/LGPL2.1")
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
