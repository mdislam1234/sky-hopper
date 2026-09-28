import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) keyPropertiesFile.inputStream().use(::load)
}
val releasePropertiesFile = rootProject.file("release.properties")
val releaseProperties = Properties().apply {
    if (releasePropertiesFile.exists()) releasePropertiesFile.inputStream().use(::load)
}
val testAdMobAppId = "ca-app-pub-3940256099942544~3347511713"
val releaseAdMobAppId = releaseProperties.getProperty("ADMOB_APP_ID", "").trim()
val signingFields = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val releaseSigningConfigured = keyPropertiesFile.exists() &&
    signingFields.all { !keyProperties.getProperty(it).isNullOrBlank() }

if (releaseRequested) {
    if (!releaseSigningConfigured) {
        throw GradleException(
            "Release signing is not configured. Copy android/key.properties.example " +
                "to android/key.properties and supply the upload-keystore values."
        )
    }
    if (!releasePropertiesFile.exists() ||
        releaseAdMobAppId == testAdMobAppId ||
        !releaseAdMobAppId.matches(Regex("ca-app-pub-[0-9]+~[0-9]+"))) {
        throw GradleException(
            "A production ADMOB_APP_ID is required in android/release.properties " +
                "for release builds; Google sample IDs are rejected."
        )
    }
}

android {
    namespace = "com.skyhopper.game"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.skyhopper.game"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["adMobAppId"] = testAdMobAppId
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("release") {
                storeFile = rootProject.file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            manifestPlaceholders["adMobAppId"] = releaseAdMobAppId
            signingConfig = signingConfigs.findByName("release")
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
