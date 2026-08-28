// swift-tools-version: 6.0
import Foundation
import PackageDescription

let engineBinaryBaseURL = "https://github.com/dooop/nestopia/releases/download/0.2.0"
let engineChecksum = "0f922199fc585a83ba836152556c2e9fce1ce84e7725cd892ece6cd0e65d32de"
let localEngineArtifactsPath = ProcessInfo.processInfo.environment["NESTOPIA_ENGINE_ARTIFACTS_DIR"]
let releasedEngineAvailable = engineChecksum != String(repeating: "0", count: 64)

// Binary mode is the consumer default after the first engine release. Source mode
// remains available for engine development and is the fallback while the manifest
// still carries the placeholder checksum. SwiftPM caches manifests, so reset the
// package when switching NESTOPIA_BUILD_FROM_SOURCE for an existing checkout.
let buildEngineFromSource =
    ProcessInfo.processInfo.environment["NESTOPIA_BUILD_FROM_SOURCE"] != nil
    || (localEngineArtifactsPath == nil && !releasedEngineAvailable)

let coreTarget: Target =
    if buildEngineFromSource {
        .target(
            name: "CNestopiaCore",
            path: "swift/Sources",
            exclude: [
                "Nestopia",
                "NestopiaCore/NstSoundRenderer.inl",
                "NestopiaCore/NstVideoFilter2xSaI.cpp",
                "NestopiaCore/NstVideoFilterHqX.cpp",
                "NestopiaCore/NstVideoFilterHq2x.inl",
                "NestopiaCore/NstVideoFilterHq3x.inl",
                "NestopiaCore/NstVideoFilterHq4x.inl",
                "NestopiaCore/NstVideoFilterScaleX.cpp",
                "NestopiaCore/NstVideoFilterxBR.cpp",
            ],
            sources: [
                "NestopiaCoreBridge",
                "NestopiaCore",
            ],
            publicHeadersPath: "NestopiaCoreBridge/include",
            cxxSettings: [
                .headerSearchPath("NestopiaCore"),
                .headerSearchPath("NestopiaCore/api"),
                .define("NST_NO_HQ2X"),
                .define("NST_NO_SCALEX"),
                .define("NST_NO_2XSAI"),
                .define("NST_NO_XBR"),
            ],
            linkerSettings: [
                .linkedLibrary("z")
            ]
        )
    } else if let localEngineArtifactsPath {
        .binaryTarget(
            name: "CNestopiaCore",
            path: "\(localEngineArtifactsPath)/CNestopiaCore.xcframework"
        )
    } else {
        .binaryTarget(
            name: "CNestopiaCore",
            url: "\(engineBinaryBaseURL)/CNestopiaCore.xcframework.zip",
            checksum: engineChecksum
        )
    }

let package = Package(
    name: "nestopia",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .macOS(.v15),
    ],
    products: [
        .library(name: "Nestopia", targets: ["Nestopia"])
    ],
    targets: [
        .target(
            name: "Nestopia",
            dependencies: ["CNestopiaCore"],
            path: "swift/Sources/Nestopia",
            resources: [
                .copy("Resources/NstDatabase.xml")
            ],
            linkerSettings: [
                .linkedLibrary("c++"),
                .linkedLibrary("z"),
            ]
        ),
        .testTarget(
            name: "NestopiaTests",
            dependencies: ["Nestopia"],
            path: "swift/Tests/NestopiaTests"
        ),
        coreTarget,
    ],
    swiftLanguageModes: [.v5],
    cxxLanguageStandard: .cxx14
)
