import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use(keystoreProperties::load)
}

fun signingProperty(name: String): String? {
    val fileValue = keystoreProperties.getProperty(name)
    return if (fileValue.isNullOrBlank()) System.getenv(name) else fileValue
}

val storeFilePath = signingProperty("storeFile")
val releaseStorePassword = signingProperty("storePassword")
val releaseKeyAlias = signingProperty("keyAlias")
val releaseKeyPassword = signingProperty("keyPassword")
val missingReleaseSigningProperties =
    listOfNotNull(
        if (storeFilePath.isNullOrBlank()) "storeFile" else null,
        if (releaseStorePassword.isNullOrBlank()) "storePassword" else null,
        if (releaseKeyAlias.isNullOrBlank()) "keyAlias" else null,
        if (releaseKeyPassword.isNullOrBlank()) "keyPassword" else null,
    )
val releaseStoreFile =
    storeFilePath
        ?.takeIf { it.isNotBlank() }
        ?.let { rootProject.file(it) }
val releaseSigningError =
    when {
        missingReleaseSigningProperties.isNotEmpty() ->
            "Missing release signing properties: ${missingReleaseSigningProperties.joinToString()}."
        releaseStoreFile?.isFile != true ->
            "Release keystore does not exist: ${releaseStoreFile?.path}."
        else -> null
    }

android {
    namespace = "com.alex47.calorietracker"
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
        applicationId = "com.alex47.calorietracker"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    if (releaseSigningError == null) {
        signingConfigs {
            create("release") {
                storeFile = requireNotNull(releaseStoreFile)
                storePassword = requireNotNull(releaseStorePassword)
                keyAlias = requireNotNull(releaseKeyAlias)
                keyPassword = requireNotNull(releaseKeyPassword)
            }
        }
    }

    buildTypes {
        release {
            signingConfigs.findByName("release")?.let {
                signingConfig = it
            }
        }
    }
}

gradle.taskGraph.whenReady {
    val releaseArtifactRequested =
        hasTask("${project.path}:assembleRelease") ||
            hasTask("${project.path}:bundleRelease") ||
            hasTask("${project.path}:packageRelease")
    if (releaseArtifactRequested && releaseSigningError != null) {
        throw GradleException(
            "$releaseSigningError Configure android/key.properties with storeFile, " +
                "storePassword, keyAlias, and keyPassword. Release builds do not fall back " +
                "to debug signing.",
        )
    }
}

flutter {
    source = "../.."
}
