plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.dkstudio.headscalemanager"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.dkstudio.headscalemanager"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            // signingConfig = debugSigningConfig // Comment out or remove this line

            // Add the following lines for release signing
            if (project.hasProperty('MYAPP_UPLOAD_STORE_FILE')) {
                signingConfig = signingConfigs.release
            }
        }
    }

    signingConfigs {
        create("release") {
            storeFile = file(System.getenv('MYAPP_UPLOAD_STORE_FILE') ?: project.property('MYAPP_UPLOAD_STORE_FILE') as String)
            storePassword = System.getenv('MYAPP_UPLOAD_STORE_PASSWORD') ?: project.property('MYAPP_UPLOAD_STORE_PASSWORD') as String
            keyAlias = System.getenv('MYAPP_UPLOAD_KEY_ALIAS') ?: project.property('MYAPP_UPLOAD_KEY_ALIAS') as String
            keyPassword = System.getenv('MYAPP_UPLOAD_KEY_PASSWORD') ?: project.property('MYAPP_UPLOAD_KEY_PASSWORD') as String
        }
    }
    }
}

flutter {
    source = "../.."
}
