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
swift build
xcodebuild -scheme nes -destination 'generic/platform=iOS' build
```

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
./gradlew :app:assembleDebug
```

The sample uses Android's document picker and declares phone, tablet, gamepad, and Android TV compatibility. Compose touch controls and Android key/gamepad events map to the same native input masks as Apple.

## ROMs and BIOS files

No commercial ROMs or firmware are included. Supply legally obtained `.nes`/`.unf` content. Famicom Disk System images require a user-supplied FDS BIOS; the initial wrapper exposes cartridge playback and Nestopia's normal missing-BIOS error but does not bundle firmware.

## License

Nestopia is GPL-2.0-or-later. Because this project links Nestopia into the produced Apple and Android binaries, distribute the corresponding source and the GPL terms with those binaries. See [LICENSE](LICENSE) and the upstream copyright notices. This is a technical notice, not legal advice.
