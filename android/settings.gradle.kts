pluginManagement {
    val flutterSdkPath =
        run {
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
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")

// flutter_libserialport 0.6.0 calls jcenter(), which Gradle 9 removed.
// Override only its Android build script, leaving the package cache untouched.
findProject(":flutter_libserialport")?.let { serialPort ->
    serialPort.buildFileName = serialPort.projectDir.toPath()
        .relativize(file("compat/flutter_libserialport.gradle").toPath())
        .toString()
}
