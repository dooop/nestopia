#!/bin/sh
set -eu

cmp LICENSE nestopia/COPYING
cmp LICENSE android/nes/src/main/assets/licenses/GPL-2.0-or-later.txt

NES_BUILD_FROM_SOURCE=1 swift package dump-package >/dev/null
NES_BUILD_FROM_SOURCE=1 swift build
NES_BUILD_FROM_SOURCE=1 swift test

if [ "${ANDROID_SDK_ROOT:-}" != "" ] || [ -f local.properties ]; then
    ./gradlew :nes:testDebugUnitTest :nes:assembleDebug :app:assembleLocalDebug :nes:lintDebug :app:lintLocalDebug
else
    echo "Android SDK not configured; skipped Gradle validation."
fi
