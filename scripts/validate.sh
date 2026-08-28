#!/bin/sh
set -eu

cmp LICENSE nestopia/COPYING
cmp LICENSE android/nestopia/src/main/assets/licenses/GPL-2.0-or-later.txt
./scripts/sync-vendored-resources.sh --check

NESTOPIA_BUILD_FROM_SOURCE=1 swift package dump-package >/dev/null
NESTOPIA_BUILD_FROM_SOURCE=1 swift build
NESTOPIA_BUILD_FROM_SOURCE=1 swift test

if [ "${ANDROID_SDK_ROOT:-}" != "" ] || [ -f local.properties ]; then
    ./gradlew :nestopia:testDebugUnitTest :nestopia:assembleDebug :app:assembleLocalDebug :nestopia:lintDebug :app:lintLocalDebug
else
    echo "Android SDK not configured; skipped Gradle validation."
fi
