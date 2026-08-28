# Nestopia

An 8-bit cartridge-console engine for Apple and Android, backed by the unmodified [Nestopia](https://github.com/0ldsk00l/nestopia) core.

The repository follows the same boundary model as `swift-scummvm`:

```text
nestopia/                 upstream git submodule; read-only
swift/
  Sources/NestopiaCore   read-only symlink into the submodule (source mode only)
  Sources/NestopiaCoreBridge  portable C/C++ facade
  Sources/Nestopia       SwiftUI library for iOS, tvOS and macOS
android/
  nestopia               Compose AAR + JNI/CMake host
  app                    phone/tablet/TV sample
scripts/                 build and validation entry points
```

The shared bridge implements ROM loading, PAL/NTSC timing, 32-bit video, mono PCM audio, two controllers, battery saves, save states, reset, and Game Genie codes directly through Nestopia's public API.

## Apple

Requirements: Xcode 16+, Swift 6 toolchain. Supported deployment targets are iOS 17+, tvOS 17+, and macOS 15+.

```swift
import Nestopia
import SwiftUI

struct GameScreen: View {
    let romURL: URL

    var body: some View {
        Nestopia(rom: romURL)
    }
}
```

Build from the repository root:

```sh
git submodule update --init
NESTOPIA_BUILD_FROM_SOURCE=1 swift build
NESTOPIA_BUILD_FROM_SOURCE=1 xcodebuild -scheme nestopia -destination 'generic/platform=iOS' build
```

### Apple package modes

The public `Nestopia` Swift target is always compiled from source. Its `CNestopiaCore` dependency can be consumed in two modes while keeping the same module graph:

- **Binary mode (consumer default after the first engine release):** SwiftPM downloads `CNestopiaCore.xcframework.zip` from the release pinned in `Package.swift`. The Nestopia submodule is not required: the cartridge database resource is vendored into `swift/Sources/Nestopia/Resources/NstDatabase.xml`, so nothing in the package graph reaches into `nestopia/`.
- **Source mode:** set `NESTOPIA_BUILD_FROM_SOURCE=1` to compile `CNestopiaCore` from the `nestopia/` submodule. Use this for engine and bridge development.

The manifest falls back to source mode while it still contains the placeholder binary checksum. Run `swift package reset` after switching modes in an existing checkout. Release automation builds iOS, iOS Simulator, tvOS, tvOS Simulator, and universal macOS slices, validates the resulting local XCFramework, and then updates the release URL and checksum through a pull request.

`Nestopia` starts on appearance and stops on disappearance. `NestopiaView(engine:)` and `NestopiaEngine` are public for hosts that need explicit lifecycle control, state slots, or custom controls. Touch controls are included. Apple game controllers and keyboards are mapped automatically (D-pad, A/B, Start/Select). Connecting an external controller hides the on-screen controls. tvOS never displays touch controls and instead asks the player to connect a controller when none is available.

The on-screen controller supports the default adaptive `system` theme plus `nes` and `famicom` themes with their original palettes. Every on-screen button provides tactile press feedback by default; set `hapticsEnabled` to `false` to disable it. Automatic presentation uses a controller body when space permits and switches to a translucent overlay in landscape or compact-height containers. The controller body uses the host app name by default; `controllerLabel` can replace it or hide it with an empty string. A host can force either mode and replace any palette color:

```swift
Nestopia(
    rom: romURL,
    controllerConfiguration: NestopiaControllerConfiguration(
        theme: .famicom,
        presentationMode: .automatic,
        controllerLabel: "My App",
        colors: NestopiaControllerColorOverrides(actionButtons: .pink)
    )
)
```

The Apple system theme uses native Liquid Glass on Apple 26 platforms and falls back to adaptive system material on earlier versions. Both variants inherit the host accent color.

## Android

Requirements: JDK 17, Android SDK 37, CMake 3.22.1, and NDK 29. The default ABIs are `arm64-v8a,x86_64`; override them with `-Pnestopia.abis=...`.

```kotlin
Nestopia(
    configuration = NestopiaConfiguration(romUri = documentUri),
    modifier = Modifier.fillMaxSize(),
)
```

Build the Compose AAR and sample APK:

```sh
./gradlew :nestopia:assembleDebug
./gradlew :app:assembleLocalDebug
```

The Android application ID is `net.sourceforge.nestopia`. The library namespace and public Kotlin package are also `net.sourceforge.nestopia`; the sample app's source namespace is `net.sourceforge.nestopia.app`.

### Android package modes

From a source checkout, depend directly on the library project:

```kotlin
implementation(project(":nestopia"))
```

Released AARs are published to GitHub Packages as `io.github.dooop:nestopia:<version>`. Configure the `https://maven.pkg.github.com/dooop/nestopia` repository with GitHub Packages credentials, then use:

```kotlin
implementation("io.github.dooop:nestopia:<version>")
```

The AAR and sample APK contain the full GPL terms under `assets/licenses/`. Maven releases also publish `nestopia-<version>-complete-source.tar.gz` with classifier `complete-source`; it contains the exact wrapper and upstream source used for the binary. Apple XCFramework archives embed the same license and source provenance at their root.

The sample has `local` and `maven` flavors. `localDebug` consumes the source project, `localRelease` consumes an AAR passed with `-Pnestopia.releaseAar=...`, and the `maven` variants consume the published package.

The sample uses Android's document picker and declares phone, tablet, gamepad, and Android TV compatibility. Compose touch controls and Android key/gamepad events map to the same native input masks as Apple, including analog sticks and up to two players. Connecting a physical controller hides the on-screen controls. Android TV never displays touch controls and instead asks the player to connect a controller when none is available.

Compose exposes the matching controller options. The system theme is derived from the surrounding Material 3 theme, including its primary, secondary, surface, and content colors:

```kotlin
Nestopia(
    configuration = NestopiaConfiguration(romUri = documentUri),
    controllerConfiguration = NestopiaControllerConfiguration(
        theme = NestopiaControllerTheme.NES,
        presentationMode = NestopiaControllerPresentationMode.Automatic,
        controllerLabel = "My App",
        colors = NestopiaControllerColorOverrides(actionButtons = Color(0xFFE91E63)),
    ),
    modifier = Modifier.fillMaxSize(),
)
```

## Save data and autosave

Both platforms keep the cartridge battery save and one automatic save state per game. Autosave is **enabled by default**: the engine restores the automatic save state right after the ROM loads, rewrites it every 30 seconds, and writes it once more on pause and on shutdown. A stale or incompatible autosave is ignored rather than failing the start.

Files are named after a stable game identity — the sanitized display name plus the first 16 hex characters of the SHA-1 digest of the ROM contents — so saves survive a renamed file or a re-picked document:

```text
<save directory>/Super-Mario-Bros-1a2b3c4d5e6f7a8b.sav       cartridge battery / EEPROM
<save directory>/Super-Mario-Bros-1a2b3c4d5e6f7a8b.auto.nst  automatic save state
```

The default save directory is `Application Support/Nestopia/Saves` on Apple platforms and `filesDir/Nestopia/Saves` on Android. Battery files written by earlier versions under their old names are moved to the new name on first start.

```swift
Nestopia(
    configuration: NestopiaConfiguration(
        romURL: romURL,
        saveDirectory: myGamesDirectory,
        autosave: NestopiaAutosaveConfiguration(isEnabled: true, interval: 60)
    )
)
```

```kotlin
Nestopia(
    configuration = NestopiaConfiguration(
        romUri = documentUri,
        saveDirectory = myGamesDirectory,
        autosave = NestopiaAutosaveConfiguration(isEnabled = true, intervalSeconds = 60),
    ),
    modifier = Modifier.fillMaxSize(),
)
```

Bridge writes go through a sibling temporary file, so an interrupted autosave never destroys the previous one; Apple binary-mode consumers pick that up with the next engine release pinned in `Package.swift`, while Android and Apple source mode compile the bridge directly.

Set `isEnabled` to `false` to turn autosave off; the battery save keeps working, because the emulated cartridge writes it. Intervals below five seconds are raised to five. `NestopiaEngine` also exposes the automatic save state directly — `autosaveURL`/`autosaveFile`, `autosave()`, and `deleteAutosave()`/`clearAutosave()` — for hosts that want an explicit "save now" or "start over" action.

## ROMs and BIOS files

No commercial ROMs or firmware are included. Supply legally obtained `.nes`/`.unf` content. Disk-system images require a user-supplied FDS BIOS; the initial wrapper exposes cartridge playback and Nestopia's normal missing-BIOS error but does not bundle firmware.

## Updating the Nestopia submodule

`swift/Sources/Nestopia/Resources/NstDatabase.xml` is a vendored copy of the upstream file, not a symlink, so that binary-mode consumers never fetch the submodule. After bumping `nestopia/`, refresh it and commit the result:

```sh
scripts/sync-vendored-resources.sh
```

CI fails if the vendored copy and the submodule diverge. Android keeps reading the file straight from the submodule, because its build always compiles the engine from source.

## License

Nestopia is GPL-2.0-or-later. This wrapper uses the same GPL-2.0-or-later license. Because it links Nestopia into the produced Apple and Android binaries, distribute the corresponding source and the complete [GPL terms](LICENSE) with those binaries. This is a technical summary, not legal advice.
