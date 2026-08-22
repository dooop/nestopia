// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "nes",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .macOS(.v15),
    ],
    products: [
        .library(name: "NES", targets: ["NES"]),
    ],
    targets: [
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
                .linkedLibrary("z"),
            ]
        ),
        .target(
            name: "NES",
            dependencies: ["CNESCore"],
            path: "swift/Sources/NES",
            resources: [
                .copy("Resources/NstDatabase.xml"),
            ]
        ),
        .testTarget(
            name: "NESTests",
            dependencies: ["NES"],
            path: "swift/Tests/NESTests"
        ),
    ],
    swiftLanguageModes: [.v5],
    cxxLanguageStandard: .cxx14
)
