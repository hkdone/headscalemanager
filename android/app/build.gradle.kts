import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.dkstudio.headscalemanager"
    compileSdk = 36 // Updated as required by plugins
    ndkVersion = "27.0.12077973"

    val keystoreProperties = Properties()
    val keystorePropertiesFile = file("C:/Users/dkdone/StudioProjects/headscaleManager/android/key.properties")
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
    }

    compileOptions {
        // Flag to enable support for the new language APIs for desugaring
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "com.dkstudio.headscalemanager"
        minSdk = flutter.minSdkVersion
        targetSdk = 35 // It is best practice to keep targetSdk a bit behind compileSdk
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    packagingOptions {
        jniLibs {
            useLegacyPackaging = false
        }
    }

    signingConfigs {
        create("release") {
            storeFile = file(rootProject.projectDir.absolutePath + "/key.jks")
            storePassword = keystoreProperties.getProperty("storePassword")
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Dependency for core library desugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
