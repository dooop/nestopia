// swift-tools-version: 6.0
import Foundation
import PackageDescription

let engineBinaryBaseURL = "https://github.com/dooop/nes/releases/download/0.0.0"
let engineChecksum = "0000000000000000000000000000000000000000000000000000000000000000"
let localEngineArtifactsPath = ProcessInfo.processInfo.environment["NES_ENGINE_ARTIFACTS_DIR"]
let releasedEngineAvailable = engineChecksum != String(repeating: "0", count: 64)

// Binary mode is the consumer default after the first engine release. Source mode
// remains available for engine development and is the fallback while the manifest
// still carries the placeholder checksum. SwiftPM caches manifests, so reset the
// package when switching NES_BUILD_FROM_SOURCE for an existing checkout.
let buildEngineFromSource =
    ProcessInfo.processInfo.environment["NES_BUILD_FROM_SOURCE"] != nil
    || (localEngineArtifactsPath == nil && !releasedEngineAvailable)

let coreTarget: Target =
    if buildEngineFromSource {
        .target(
            name: "CNESCore",
            path: "swift/Sources",
            exclude: [
                "NES",
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
                "NESCoreBridge",
                "NestopiaCore",
            ],
            publicHeadersPath: "NESCoreBridge/include",
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
            name: "CNESCore",
            path: "\(localEngineArtifactsPath)/CNESCore.xcframework"
        )
    } else {
        .binaryTarget(
            name: "CNESCore",
            url: "\(engineBinaryBaseURL)/CNESCore.xcframework.zip",
            checksum: engineChecksum
        )
    }

let package = Package(
    name: "nes",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .macOS(.v15),
    ],
    products: [
        .library(name: "NES", targets: ["NES"])
    ],
    targets: [
        .target(
            name: "NES",
            dependencies: ["CNESCore"],
            path: "swift/Sources/NES",
            resources: [
                .copy("Resources/NstDatabase.xml")
            ],
            linkerSettings: [
                .linkedLibrary("c++"),
                .linkedLibrary("z"),
            ]
        ),
        .testTarget(
            name: "NESTests",
            dependencies: ["NES"],
            path: "swift/Tests/NESTests"
        ),
        coreTarget,
    ],
    swiftLanguageModes: [.v5],
    cxxLanguageStandard: .cxx14
)
