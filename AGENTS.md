# Repository instructions

## Mission

- Provide thin SwiftUI and Android Compose wrappers around upstream Nestopia.
- Reuse one portable C/C++ bridge and one unmodified `nestopia/` git submodule.
- Keep the public Apple and Android APIs behaviorally aligned where the platforms permit it.

## Architecture

- `nestopia/`: read-only upstream git submodule.
- `swift/Sources/NestopiaCoreBridge/`: portable C ABI and C++ integration shared by both platforms.
- `swift/Sources/Nestopia/`: SwiftUI API, Apple lifecycle, video, audio, and controller handling.
- `android/nestopia/`: Android library, Compose UI, lifecycle, JNI, and CMake host.
- `android/app/`: sample-only Android application.
- `swift/Tests/` and Android test source sets: wrapper tests; never put tests in the submodule.

## Non-negotiable boundaries

- Never edit, delete, reformat, patch, or generate files under `nestopia/`.
- Preserve one engine per process. Nestopia callback managers are global; every success, failure, cancellation, and disposal path must release the process claim exactly once.
- Serialize all calls that touch a native engine. Do not destroy an engine while frame, audio, input, state, or file callbacks can still use it.
- Put portable emulator behavior in `swift/Sources/NestopiaCoreBridge/`, not in JNI or Swift.
- Keep platform lifecycle, storage access, rendering, audio output, and controls in their platform layer.
- Do not commit `.build/`, `.gradle/`, `.kotlin/`, `**/.cxx/`, `**/build/`, `DerivedData/`, APKs, AARs, archives, or local SDK configuration.
- Do not add ROMs, BIOS images, firmware, copyrighted game assets, secrets, or machine-local paths.

## Change workflow

- Inspect `git status --short` before editing and preserve unrelated user changes.
- Classify the change before choosing a layer: core behavior, Apple host, Android host, or sample-only.
- When the C ABI changes, update the header and implementation together, then audit both Swift imports and Android JNI/Kotlin bindings.
- When a public capability changes on one platform, explicitly check whether the other platform needs the same behavior or documentation.
- After bumping the `nestopia/` submodule, run `scripts/sync-vendored-resources.sh`; the Apple package ships `NstDatabase.xml` as a vendored copy so binary-mode consumers never need the submodule.
- Keep JNI limited to type conversion and buffer transfer. Keep Swift and Kotlin wrappers thin.
- Add focused regression tests for state transitions, lifecycle cleanup, input masks, storage identity, and error paths when those areas change.
- Treat hard-coded user-facing strings in library code as localization debt; keep diagnostic messages consistent across platforms.

## Runtime review rules

- Flag invalid state transitions such as `resume` without a loaded engine or `pause` after failure/stop.
- Flag terminal paths that leak the native handle, audio object, callback registration, executor/timer, security-scoped access, or engine claim.
- Flag per-frame allocation or copying added to the hot path unless it is measured and justified.
- Flag save/battery naming based only on a display filename or unstable URI hash; persistent data needs a stable collision-resistant game identity.
- Validate JNI array lengths and null handles at the native boundary even when the current Kotlin caller supplies fixed-size arrays.
- Keep audio/video timing driven by the emulated machine mode and avoid unbounded audio queue growth.
- Reset pressed inputs on pause, focus loss, controller disconnect, stop, and failed startup where applicable.

## Validation

Run the narrowest relevant checks while iterating, then the full affected platform checks before handoff.

- Manifest: `swift package dump-package > /dev/null`
- Apple host: `swift build`
- Apple tests: `swift test`
- iOS: `xcodebuild -scheme nestopia -destination 'generic/platform=iOS' build`
- Android library: `./gradlew :nestopia:assembleDebug`
- Android sample from source: `./gradlew :app:assembleLocalDebug`
- Android sample from AAR: `./gradlew :app:assembleLocalRelease -Pnestopia.releaseAar=/absolute/path/to/nestopia-release.aar`
- Android lint: `./gradlew :nestopia:lintDebug :app:lintLocalDebug`
- Combined local validation: `./scripts/validate.sh`

After validation, run `git status --short` and ensure only intended source/configuration files changed. Generated output must remain ignored and untracked.

## Licensing

Nestopia is GPL-2.0-or-later. Treat linked binaries and distributed wrappers as GPL-covered work. Keep the `LICENSE` link valid and ship corresponding source, build instructions, license terms, and upstream notices with distributed Apple or Android binaries.

## Project skills

- Use `$develop-nes-wrappers` for implementation, refactoring, lifecycle, native bridge, SwiftUI, Compose, or JNI work.
- Use `$validate-nes-wrappers` for build verification, lint triage, release readiness, or GPL packaging checks.
