---
name: develop-nes-wrappers
description: Safely implements and reviews features, fixes, and refactors in the shared Nestopia C++ bridge, SwiftUI Apple wrapper, Android Compose wrapper, or JNI layer. Use for emulator lifecycle, ROM loading, audio/video frames, controls, save data, save states, cheats, platform API parity, or native boundary changes in this repository. Do not use for validation-only or release-check tasks.
---

# Develop NES wrappers

Follow `AGENTS.md` before applying this workflow.

## Locate the responsibility

1. Inspect `git status --short` and the directly affected code.
2. Put emulator behavior and shared state in `swift/Sources/NESCoreBridge/`.
3. Put only marshaling and buffer conversion in `android/nes/src/main/cpp/nes_jni.cpp`.
4. Put lifecycle, storage access, presentation, audio output, and input adapters in the platform library.
5. Keep sample behavior in `android/app/`.
6. Never modify `nestopia/`; adapt through its public API.

## Preserve the cross-platform contract

For a shared capability, audit this chain:

```text
nes_engine.h <-> nes_engine.cpp
    |-> Swift NESEngine -> SwiftUI/public Apple API
    `-> JNI -> NativeNES -> Kotlin NESEngine -> Compose/public Android API
```

Keep button masks, dimensions, sample formats, state semantics, errors, and persistent-data behavior aligned. If parity is intentionally impossible, document the platform difference.

## Protect lifecycle and concurrency

- Maintain one native engine per process at the lowest practical layer.
- Serialize every native operation and destruction.
- Define valid transitions among idle, loading, running, paused, stopped, and failed.
- Make pause/resume no-ops when the engine is not loaded.
- On every terminal path, stop scheduling work, stop/release audio, destroy the handle, unregister callbacks, release storage access, reset inputs, and release the process claim exactly once.
- Account for stop during loading, lifecycle events during startup, repeated start/stop, frame failure, controller disconnect, and object deinitialization.

## Protect the frame path

- Avoid new per-frame bitmap, image, data, and audio-buffer allocations where reusable storage works.
- Bound audio buffering and derive timing/sample counts from the native machine mode.
- Validate destination capacities at C and JNI boundaries.
- Keep expensive file I/O and ROM hashing outside the frame loop.

## Persist data safely

- Derive battery/save identity from stable content metadata or a collision-resistant digest, not only a filename or language/runtime hash.
- Write state and battery files atomically when changing persistence behavior.
- Preserve existing saves or provide a migration when changing paths or identifiers.

## Verify

Add focused tests for the changed contract and then invoke `$validate-nes-wrappers` with the affected scope. Report any capability intentionally left asymmetric.
