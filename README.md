# nes

A NES/Famicom engine for Apple and Android, backed by the unmodified [Nestopia](https://github.com/0ldsk00l/nestopia) core.

The repository follows the same boundary model as `swift-scummvm`:

```text
nestopia/                 upstream git submodule; read-only
swift/
  Sources/NestopiaCore   read-only symlink into the submodule
  Sources/NESCoreBridge  portable C/C++ facade
  Sources/NES            SwiftUI library for iOS, tvOS and macOS
android/
  nes                    Compose AAR + JNI/CMake host
  app                    phone/tablet/TV sample
scripts/                 build and validation entry points
```

The shared bridge implements ROM loading, PAL/NTSC timing, 32-bit video, mono PCM audio, two controllers, battery saves, save states, reset, and Game Genie codes directly through Nestopia's public API.

## Apple

Requirements: Xcode 16+, Swift 6 toolchain. Supported deployment targets are iOS 17+, tvOS 17+, and macOS 15+.

```swift
import NES
import SwiftUI

struct GameScreen: View {
    let romURL: URL

    var body: some View {
        NES(rom: romURL)
    }
}
```

Build from the repository root:

```sh
git submodule update --init
NES_BUILD_FROM_SOURCE=1 swift build
NES_BUILD_FROM_SOURCE=1 xcodebuild -scheme nes -destination 'generic/platform=iOS' build
```

### Apple package modes

The public `NES` Swift target is always compiled from source. Its `CNESCore` dependency can be consumed in two modes while keeping the same module graph:

- **Binary mode (consumer default after the first engine release):** SwiftPM downloads `CNESCore.xcframework.zip` from the release pinned in `Package.swift`. The Nestopia submodule is not required.
- **Source mode:** set `NES_BUILD_FROM_SOURCE=1` to compile `CNESCore` from the `nestopia/` submodule. Use this for engine and bridge development.

The manifest falls back to source mode while it still contains the placeholder binary checksum. Run `swift package reset` after switching modes in an existing checkout. Release automation builds iOS, iOS Simulator, tvOS, tvOS Simulator, and universal macOS slices, validates the resulting local XCFramework, and then updates the release URL and checksum through a pull request.

`NES` starts on appearance and stops on disappearance. `NESView(engine:)` and `NESEngine` are public for hosts that need explicit lifecycle control, state slots, or custom controls. Touch controls are included. Apple game controllers and keyboards are mapped automatically (D-pad, A/B, Start/Select).

## Android

Requirements: JDK 17, Android SDK 37, CMake 3.22.1, and NDK 29. The default ABIs are `arm64-v8a,x86_64`; override them with `-Pnes.abis=...`.

```kotlin
NES(
    configuration = NESConfiguration(romUri = documentUri),
    modifier = Modifier.fillMaxSize(),
)
```

Build the Compose AAR and sample APK:

```sh
./gradlew :nes:assembleDebug
./gradlew :app:assembleLocalDebug
```

The Android application id is `nestopia.app` (Android application IDs require at least two
segments); the library namespace and public Kotlin package are `nestopia`.

### Android package modes

From a source checkout, depend directly on the library project:

```kotlin
implementation(project(":nes"))
```

Released AARs are published to GitHub Packages as `io.github.dooop:nes:<version>`. Configure the `https://maven.pkg.github.com/dooop/nes` repository with GitHub Packages credentials, then use:

```kotlin
implementation("io.github.dooop:nes:<version>")
```

The sample has `local` and `maven` flavors. `localDebug` consumes the source project, `localRelease` consumes an AAR passed with `-Pnes.releaseAar=...`, and the `maven` variants consume the published package.

The sample uses Android's document picker and declares phone, tablet, gamepad, and Android TV compatibility. Compose touch controls and Android key/gamepad events map to the same native input masks as Apple.

## ROMs and BIOS files

No commercial ROMs or firmware are included. Supply legally obtained `.nes`/`.unf` content. Famicom Disk System images require a user-supplied FDS BIOS; the initial wrapper exposes cartridge playback and Nestopia's normal missing-BIOS error but does not bundle firmware.

## License

Nestopia is GPL-2.0-or-later. Because this project links Nestopia into the produced Apple and Android binaries, distribute the corresponding source and the GPL terms with those binaries. See [LICENSE](LICENSE) and the upstream copyright notices. This is a technical notice, not legal advice.
