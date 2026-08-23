plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.ktlint)
    `maven-publish`
}

group = "io.github.dooop"
version = providers.gradleProperty("nestopia.version").getOrElse("0.0.0-SNAPSHOT")

ktlint {
    android.set(true)
    outputToConsole.set(true)
}

val configuredAbis =
    providers
        .gradleProperty("nestopia.abis")
        .getOrElse("arm64-v8a,x86_64")
        .split(",")
        .map(String::trim)
        .filter(String::isNotEmpty)

android {
    namespace = "net.sourceforge.nestopia"
    compileSdk { version = release(37) }
    enableKotlin = true
    ndkVersion = providers.gradleProperty("nestopia.ndkVersion").get()

    defaultConfig {
        minSdk = 23
        consumerProguardFiles("consumer-rules.pro")
        ndk { abiFilters += configuredAbis }
        externalNativeBuild {
            cmake {
                cppFlags += listOf("-std=c++14", "-fexceptions", "-frtti")
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    buildFeatures { compose = true }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    lint { abortOnError = true }
    publishing {
        singleVariant("release") {
            withSourcesJar()
        }
    }
}

dependencies {
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.foundation)
    implementation(libs.compose.material3)
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.kotlinx.coroutines.android)
    testImplementation(libs.junit)
}

afterEvaluate {
    publishing {
        publications {
            create<MavenPublication>("release") {
                from(components["release"])
                artifactId = "nestopia"
                providers.gradleProperty("nestopia.completeSourceArchive").orNull?.let { archivePath ->
                    artifact(file(archivePath)) {
                        classifier = "complete-source"
                        extension = "tar.gz"
                    }
                }
                pom {
                    name.set("nestopia")
                    description.set("SwiftUI and Android Compose wrappers around Nestopia")
                    url.set("https://github.com/dooop/nestopia")
                    licenses {
                        license {
                            name.set("GNU General Public License v2.0 or later")
                            url.set("https://github.com/dooop/nestopia/blob/main/LICENSE")
                            distribution.set("repo")
                        }
                    }
                    scm {
                        url.set("https://github.com/dooop/nestopia")
                        connection.set("scm:git:https://github.com/dooop/nestopia.git")
                        developerConnection.set("scm:git:ssh://git@github.com/dooop/nestopia.git")
                    }
                }
            }
        }
        repositories {
            maven {
                name = "GitHubPackages"
                url =
                    uri(
                        "https://maven.pkg.github.com/${providers.gradleProperty(
                            "nestopia.githubRepository",
                        ).getOrElse("dooop/nestopia")}",
                    )
                credentials {
                    username =
                        providers
                            .gradleProperty("gpr.user")
                            .orElse(providers.environmentVariable("GITHUB_ACTOR"))
                            .orNull
                    password =
                        providers
                            .gradleProperty("gpr.key")
                            .orElse(providers.environmentVariable("GITHUB_TOKEN"))
                            .orNull
                }
            }
        }
    }
}
