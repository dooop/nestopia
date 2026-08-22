#!/bin/sh
set -eu

swift package dump-package >/dev/null
swift build

if [ "${ANDROID_SDK_ROOT:-}" != "" ] || [ -f local.properties ]; then
    ./gradlew :nes:assembleDebug :app:assembleDebug
else
    echo "Android SDK not configured; skipped Gradle validation."
fi
