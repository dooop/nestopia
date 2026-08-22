# Repository instructions

## Goal

- Provide thin SwiftUI and Android Compose wrappers around upstream Nestopia.
- Reuse one shared C++ bridge and one unmodified `nestopia/` git submodule.
- Keep Apple code in `swift/` and Android code in `android/`.

## Boundaries

- Never edit, delete, reformat, or patch files under `nestopia/`.
- Put portable native integration in `swift/Sources/NESCoreBridge/`.
- Keep SwiftUI code in `swift/Sources/NES/`.
- Keep Android UI and lifecycle code in `android/nes/`; keep sample-only code in `android/app/`.
- Do not commit generated output from `.build/`, `.gradle/`, `**/build/`, or `DerivedData/`.
- Preserve the one-engine-per-process lifecycle because Nestopia's callback managers are global.

## Validation

- Manifest: `swift package dump-package > /dev/null`
- Apple host: `swift build`
- iOS: `xcodebuild -scheme nes -destination 'generic/platform=iOS' build`
- Android library: `./gradlew :nes:assembleDebug`
- Android sample: `./gradlew :app:assembleDebug`

## Licensing

Nestopia is GPL-2.0-or-later. Treat linked binaries and distributed wrappers as GPL-covered work and ship corresponding source plus license notices.
