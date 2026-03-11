import java.util.Properties
import java.io.FileInputStream
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load local.properties for API keys
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

val googleMapsApiKey = localProperties
    .getProperty("GOOGLE_MAPS_API_KEY", "")
    .trim()

if (googleMapsApiKey.isEmpty()) {
    throw GradleException(
        "GOOGLE_MAPS_API_KEY is missing in android/local.properties. " +
            "Add GOOGLE_MAPS_API_KEY=<your_key> and rebuild.",
    )
}

android {
    namespace = "com.example.lounge_owner_app"
    compileSdk = 36  // Match dependencies requiring SDK 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.lounge_owner_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion  // Ensure minimum SDK is set
        targetSdk = 36  // Match compileSdk and dependencies
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Inject Google Maps API Key from local.properties
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = googleMapsApiKey
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")

            // Disable minification and shrinking for now (larger APK but avoids ProGuard/R8 issues)
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    lint {
        disable += "TypographyFractions"
        disable += "MissingTranslation"
        disable += "ExtraTranslation"
        disable += "RtlSymmetry"
        disable += "MissingDimensionResource"
        disable += "MissingQualifiers"
        checkGeneratedSources = false
    }

    packagingOptions {
        resources {
            excludes += "/META-INF/proguard/androidx-*.pro"
        }
    }
}

flutter {
    source = "../.."
}
