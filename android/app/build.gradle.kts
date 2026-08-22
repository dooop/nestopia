plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.ktlint)
}

ktlint {
    android.set(true)
    outputToConsole.set(true)
}

val releaseAar =
    providers.gradleProperty("nes.releaseAar").orElse(
        layout.projectDirectory
            .file("libs/nes-release.aar")
            .asFile.absolutePath,
    )

val mavenVersion = providers.gradleProperty("nes.mavenVersion").getOrElse("0.0.0")

val configuredAbis =
    providers
        .gradleProperty("nes.abis")
        .getOrElse("arm64-v8a,x86_64")
        .split(",")
        .map(String::trim)
        .filter(String::isNotEmpty)

android {
    namespace = "nestopia.app"
    compileSdk { version = release(37) }
    enableKotlin = true

    defaultConfig {
        applicationId = "nestopia.app"
        minSdk = 23
        targetSdk = 37
        versionCode = 1
        versionName = "1.0"
        ndk { abiFilters += configuredAbis }
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }
    flavorDimensions += "engineSource"
    productFlavors {
        create("local") {
            dimension = "engineSource"
            buildConfigField("String", "ENGINE_SOURCE", "\"local\"")
        }
        create("maven") {
            dimension = "engineSource"
            versionNameSuffix = "-maven"
            buildConfigField("String", "ENGINE_SOURCE", "\"maven:io.github.dooop:nes:$mavenVersion\"")
        }
    }
    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
        release {
            isMinifyEnabled = false
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    lint { abortOnError = true }
}

dependencies {
    "mavenImplementation"("io.github.dooop:nes:$mavenVersion")
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.foundation)
    implementation(libs.compose.material3)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.core.ktx)
}

afterEvaluate {
    dependencies {
        "localDebugImplementation"(project(":nes"))
        "localReleaseImplementation"(files(releaseAar))
    }
}

val verifyReleaseAar =
    tasks.register("verifyReleaseAar") {
        group = "verification"
        description = "Checks that the prebuilt nestopia AAR exists."
        doLast {
            val aar = file(releaseAar.get())
            require(aar.isFile) {
                "The local release build requires a prebuilt nestopia AAR at ${aar.path}. " +
                    "Pass -Pnes.releaseAar=/absolute/path/to/nes-release.aar."
            }
        }
    }

tasks.configureEach {
    if (name == "preLocalReleaseBuild") dependsOn(verifyReleaseAar)
}
