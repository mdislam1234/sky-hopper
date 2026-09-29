import java.util.Properties
import java.util.Base64
import java.nio.charset.StandardCharsets
import groovy.json.JsonSlurper

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}
val developmentAndroidBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("debug", ignoreCase = true) ||
        it.contains("profile", ignoreCase = true)
}
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) keyPropertiesFile.inputStream().use(::load)
}

fun decodeDartDefines(encodedDefines: String?): Map<String, String> {
    if (encodedDefines.isNullOrBlank()) return emptyMap()
    return encodedDefines.split(',').mapNotNull { encoded ->
        val decoded = runCatching {
            String(Base64.getDecoder().decode(encoded), StandardCharsets.UTF_8)
        }.getOrNull() ?: return@mapNotNull null
        val separator = decoded.indexOf('=')
        if (separator <= 0) return@mapNotNull null
        decoded.substring(0, separator) to decoded.substring(separator + 1)
    }.toMap()
}

val dartDefines = decodeDartDefines(project.findProperty("dart-defines")?.toString())
val googleSamplePublisherId = "3940256099942544"
val releaseAdMobAppId = dartDefines["ADMOB_ANDROID_APP_ID"].orEmpty().trim()
val releaseRewardedAdUnitId = dartDefines["ADMOB_REWARDED_AD_UNIT_ID"].orEmpty().trim()
val releaseInterstitialAdUnitId = dartDefines["ADMOB_INTERSTITIAL_AD_UNIT_ID"].orEmpty().trim()
val appIdPattern = Regex("^ca-app-pub-([0-9]{16})~[0-9]{10}$")
val adUnitIdPattern = Regex("^ca-app-pub-([0-9]{16})/[0-9]{10}$")
val localAdMobConfigFile = rootProject.file("admob_config.local.json")
val debugAdMobAppId = if (developmentAndroidBuildRequested) {
    if (!localAdMobConfigFile.exists()) {
        throw GradleException(
            "Missing debug AdMob App ID configuration. Copy " +
                "android/admob_config.local.json.example to the ignored " +
                "android/admob_config.local.json and set ADMOB_ANDROID_APP_ID."
        )
    }
    val localConfig = runCatching {
        JsonSlurper().parse(localAdMobConfigFile) as? Map<*, *>
    }.getOrElse {
        throw GradleException(
            "Malformed android/admob_config.local.json. Expected a JSON object."
        )
    }
    localConfig?.get("ADMOB_ANDROID_APP_ID")?.toString()?.trim().orEmpty()
} else {
    ""
}
if (developmentAndroidBuildRequested) {
    val debugAppMatch = appIdPattern.matchEntire(debugAdMobAppId)
    if (debugAppMatch == null ||
        debugAppMatch.groupValues[1] == googleSamplePublisherId
    ) {
        throw GradleException(
            "Debug Android builds require the real Sky Hopper AdMob App ID in " +
                "android/admob_config.local.json. Google sample and malformed App IDs " +
                "are rejected."
        )
    }
}
val signingFields = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val releaseSigningConfigured = keyPropertiesFile.exists() &&
    signingFields.all { !keyProperties.getProperty(it).isNullOrBlank() }

if (releaseRequested) {
    val requiredAdMobValues = mapOf(
        "ADMOB_ANDROID_APP_ID" to releaseAdMobAppId,
        "ADMOB_REWARDED_AD_UNIT_ID" to releaseRewardedAdUnitId,
        "ADMOB_INTERSTITIAL_AD_UNIT_ID" to releaseInterstitialAdUnitId,
    )
    val missingAdMobNames = requiredAdMobValues
        .filterValues { it.isBlank() }
        .keys
    if (missingAdMobNames.isNotEmpty()) {
        throw GradleException(
            "Missing production AdMob configuration: ${missingAdMobNames.joinToString()}. " +
                "Copy android/admob_config.local.json.example to the ignored " +
                "android/admob_config.local.json and pass it with --dart-define-from-file."
        )
    }
    val appMatch = appIdPattern.matchEntire(releaseAdMobAppId)
    val rewardedMatch = adUnitIdPattern.matchEntire(releaseRewardedAdUnitId)
    val interstitialMatch = adUnitIdPattern.matchEntire(releaseInterstitialAdUnitId)
    if (appMatch == null || rewardedMatch == null || interstitialMatch == null) {
        throw GradleException(
            "Malformed production AdMob configuration. Expected one Android app ID " +
                "and two ad unit IDs in standard ca-app-pub format."
        )
    }
    val publisherIds = setOf(
        appMatch.groupValues[1],
        rewardedMatch.groupValues[1],
        interstitialMatch.groupValues[1],
    )
    if (googleSamplePublisherId in publisherIds) {
        throw GradleException(
            "Google sample/test AdMob IDs are forbidden in release builds."
        )
    }
    if (publisherIds.size != 1) {
        throw GradleException(
            "The production AdMob app and ad units must use the same publisher ID."
        )
    }
    if (!releaseSigningConfigured) {
        throw GradleException(
            "Release signing is not configured. Copy android/key.properties.example " +
                "to android/key.properties and supply the upload-keystore values."
        )
    }
}

android {
    namespace = "com.azitechstudio.skyhopper"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.azitechstudio.skyhopper"
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
        manifestPlaceholders["adMobAppId"] = debugAdMobAppId
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
            proguardFiles("proguard-rules.pro")
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
