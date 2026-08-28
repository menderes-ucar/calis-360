pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"

    // Tek Android Gradle Plugin sürümü.
    id("com.android.application") version "8.7.3" apply false

    // firebase-auth 24.2.x Kotlin 2.3 metadata ile derlendiği için
    // Kotlin Gradle Plugin 2.3.x kullanıyoruz.
    id("org.jetbrains.kotlin.android") version "2.3.0" apply false

    // Güncel Google Services Gradle plugin.
    id("com.google.gms.google-services") version "4.5.0" apply false
}

include(":app")
