#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <slice-id> <output-directory>" >&2
    exit 2
fi

SLICE_ID="$1"
OUTPUT_DIR="$2"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

case "$OUTPUT_DIR" in
    ""|"/"|"."|"$REPO_ROOT"|"$REPO_ROOT/")
        echo "Refusing unsafe output directory: $OUTPUT_DIR" >&2
        exit 2
        ;;
esac

case "$SLICE_ID" in
    ios-arm64)
        DESTINATION="generic/platform=iOS"
        ARCHS="arm64"
        ;;
    ios-arm64_x86_64-simulator)
        DESTINATION="generic/platform=iOS Simulator"
        ARCHS="arm64 x86_64"
        ;;
    tvos-arm64)
        DESTINATION="generic/platform=tvOS"
        ARCHS="arm64"
        ;;
    tvos-arm64_x86_64-simulator)
        DESTINATION="generic/platform=tvOS Simulator"
        ARCHS="arm64 x86_64"
        ;;
    macos-arm64_x86_64)
        DESTINATION="generic/platform=macOS"
        ARCHS="arm64 x86_64"
        ;;
    *)
        echo "Unknown slice: $SLICE_ID" >&2
        exit 2
        ;;
esac

export NESTOPIA_BUILD_FROM_SOURCE=1

cd "$REPO_ROOT"
xcodebuild build -quiet \
    -scheme nestopia \
    -destination "$DESTINATION" \
    -configuration Release \
    -derivedDataPath "$WORK_DIR/DerivedData" \
    ARCHS="$ARCHS" \
    ONLY_ACTIVE_ARCH=NO \
    CLANG_ENABLE_CODE_COVERAGE=NO \
    GCC_GENERATE_TEST_COVERAGE_FILES=NO \
    GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=NO \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO

PRODUCT_DIR="$WORK_DIR/DerivedData/Build/Products"
OBJECT="$(find "$PRODUCT_DIR" -maxdepth 3 -type f -name 'CNestopiaCore.o' -print -quit)"
if [ -z "$OBJECT" ]; then
    echo "CNestopiaCore.o was not produced for $SLICE_ID" >&2
    find "$PRODUCT_DIR" -maxdepth 3 -type f -print >&2 || true
    exit 1
fi

FRAMEWORK_DIR="$OUTPUT_DIR/CNestopiaCore.framework"

rm -rf "$OUTPUT_DIR"
if [ "$SLICE_ID" = "macos-arm64_x86_64" ]; then
    FRAMEWORK_CONTENTS="$FRAMEWORK_DIR/Versions/A"
    FRAMEWORK_HEADERS="$FRAMEWORK_CONTENTS/Headers"
    FRAMEWORK_MODULES="$FRAMEWORK_CONTENTS/Modules"
    FRAMEWORK_RESOURCES="$FRAMEWORK_CONTENTS/Resources"
    FRAMEWORK_BINARY="$FRAMEWORK_CONTENTS/CNestopiaCore"
    FRAMEWORK_PLIST="$FRAMEWORK_RESOURCES/Info.plist"

    mkdir -p "$FRAMEWORK_HEADERS" "$FRAMEWORK_MODULES" "$FRAMEWORK_RESOURCES"
    ln -s A "$FRAMEWORK_DIR/Versions/Current"
    ln -s Versions/Current/CNestopiaCore "$FRAMEWORK_DIR/CNestopiaCore"
    ln -s Versions/Current/Headers "$FRAMEWORK_DIR/Headers"
    ln -s Versions/Current/Modules "$FRAMEWORK_DIR/Modules"
    ln -s Versions/Current/Resources "$FRAMEWORK_DIR/Resources"
else
    FRAMEWORK_HEADERS="$FRAMEWORK_DIR/Headers"
    FRAMEWORK_MODULES="$FRAMEWORK_DIR/Modules"
    FRAMEWORK_BINARY="$FRAMEWORK_DIR/CNestopiaCore"
    FRAMEWORK_PLIST="$FRAMEWORK_DIR/Info.plist"
    mkdir -p "$FRAMEWORK_HEADERS" "$FRAMEWORK_MODULES"
fi

xcrun libtool -static -o "$FRAMEWORK_BINARY" "$OBJECT"
xcrun strip -S "$FRAMEWORK_BINARY"
cp swift/Sources/NestopiaCoreBridge/include/nestopia_engine.h "$FRAMEWORK_HEADERS/"

cat > "$FRAMEWORK_HEADERS/CNestopiaCore.h" <<'EOF'
#include "nestopia_engine.h"
EOF

cat > "$FRAMEWORK_MODULES/module.modulemap" <<'EOF'
framework module CNestopiaCore {
    umbrella header "CNestopiaCore.h"
    export *
    module * { export * }
}
EOF

cat > "$FRAMEWORK_PLIST" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>CNestopiaCore</string>
    <key>CFBundleIdentifier</key>
    <string>net.sourceforge.nestopia.CNestopiaCore</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>CNestopiaCore</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
</dict>
</plist>
EOF

echo "Built $SLICE_ID: $(lipo -archs "$FRAMEWORK_BINARY")"
