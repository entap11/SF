plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

val pluginName = "SwarmfrontSecureCredentials"
val pluginPackageName = "com.swarmfront.securecredentials"

android {
    namespace = pluginPackageName
    compileSdk = 36

    defaultConfig {
        minSdk = 24
        manifestPlaceholders["godotPluginName"] = pluginName
        manifestPlaceholders["godotPluginPackageName"] = pluginPackageName
        setProperty("archivesBaseName", pluginName)
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation("org.godotengine:godot:4.7.1.stable")
}

val projectAddons = rootProject.projectDir.resolve("../../../addons/swarmfront_secure_credentials/bin")

tasks.register<Copy>("installDebugPlugin") {
    dependsOn("assembleDebug")
    from(layout.buildDirectory.dir("outputs/aar"))
    include("$pluginName-debug.aar")
    into(projectAddons.resolve("debug"))
}

tasks.register<Copy>("installReleasePlugin") {
    dependsOn("assembleRelease")
    from(layout.buildDirectory.dir("outputs/aar"))
    include("$pluginName-release.aar")
    into(projectAddons.resolve("release"))
}
