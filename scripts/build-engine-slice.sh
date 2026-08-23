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

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/Headers"
xcrun libtool -static -o "$OUTPUT_DIR/libCNestopiaCore.a" "$OBJECT"
xcrun strip -S "$OUTPUT_DIR/libCNestopiaCore.a"
cp swift/Sources/NestopiaCoreBridge/include/nestopia_engine.h "$OUTPUT_DIR/Headers/"

cat > "$OUTPUT_DIR/Headers/module.modulemap" <<'EOF'
module CNestopiaCore {
    header "nestopia_engine.h"
    export *
}
EOF

echo "Built $SLICE_ID: $(lipo -archs "$OUTPUT_DIR/libCNestopiaCore.a")"
