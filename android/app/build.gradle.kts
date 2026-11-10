plugins {
    id("com.android.application")
    id("kotlin-android")
    // يجب أن يأتي بعد إضافتي Android و Kotlin
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // يجب أن يطابق حزمة MainActivity.kt التي يولّدها:
    // flutter create --org com.agentphone --project-name agentphone --platforms=android .
    namespace = "com.agentphone.agentphone"
    // Flutter 3.47 => compileSdk 36 (المكتبة تحتاج 35+)
    compileSdk = flutter.compileSdkVersion
    // استخدم NDK الافتراضي مع Flutter الحديث (r27+ مطلوب لتوافق صفحات 16KB)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.agentphone.agentphone"
        // llama_flutter_android يتطلب API 26+ (SharedMemory)؛ A52 يعمل بـ API 30+
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // المكتبة تُبنى لـ arm64-v8a فقط (وهي معمارية A52).
        // لتقليل حجم APK استخدم: flutter build apk --release --split-per-abi
        // ndk { abiFilters.addAll(listOf("arm64-v8a")) }
    }

    buildTypes {
        release {
            // استبدل هذا بتوقيعك الخاص قبل النشر
            signingConfig = signingConfigs.getByName("debug")
            // إن فعّلت R8 فملف proguard-rules.pro جاهز
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
