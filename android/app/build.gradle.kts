plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

val configuredAbis =
    providers.gradleProperty("nes.abis").getOrElse("arm64-v8a,x86_64")
        .split(",")
        .map(String::trim)
        .filter(String::isNotEmpty)

android {
    namespace = "org.nestopia.sample"
    compileSdk { version = release(37) }
    enableKotlin = true

    defaultConfig {
        applicationId = "org.nestopia.sample"
        minSdk = 23
        targetSdk = 37
        versionCode = 1
        versionName = "1.0"
        ndk { abiFilters += configuredAbis }
    }

    buildFeatures { compose = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    lint { abortOnError = false }
}

dependencies {
    implementation(project(":nes"))
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.foundation)
    implementation(libs.compose.material3)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.core.ktx)
}
