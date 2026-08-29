#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <slices-directory> <output-directory>" >&2
    exit 2
fi

SLICES_DIR="$(cd "$1" && pwd)"
OUTPUT_DIR="$2"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "$OUTPUT_DIR" in
    ""|"/"|"."|"$REPO_ROOT"|"$REPO_ROOT/")
        echo "Refusing unsafe output directory: $OUTPUT_DIR" >&2
        exit 2
        ;;
esac

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

ARGS=()
for slice in \
    ios-arm64 \
    ios-arm64_x86_64-simulator \
    tvos-arm64 \
    tvos-arm64_x86_64-simulator \
    macos-arm64_x86_64; do
    framework="$SLICES_DIR/$slice/CNestopiaCore.framework"
    test -f "$framework/CNestopiaCore" || { echo "Missing slice framework binary: $framework/CNestopiaCore" >&2; exit 1; }
    test -f "$framework/Headers/nestopia_engine.h" || { echo "Missing framework headers: $framework/Headers" >&2; exit 1; }
    test -f "$framework/Modules/module.modulemap" || { echo "Missing framework module map: $framework/Modules/module.modulemap" >&2; exit 1; }
    ARGS+=(-framework "$framework")
done

rm -rf "$OUTPUT_DIR/CNestopiaCore.xcframework" "$OUTPUT_DIR/CNestopiaCore.xcframework.zip"
xcodebuild -create-xcframework "${ARGS[@]}" -output "$OUTPUT_DIR/CNestopiaCore.xcframework"

for entry in \
    "ios-arm64|Info.plist|MinimumOSVersion|17.0|iPhoneOS" \
    "ios-arm64_x86_64-simulator|Info.plist|MinimumOSVersion|17.0|iPhoneSimulator" \
    "tvos-arm64|Info.plist|MinimumOSVersion|17.0|AppleTVOS" \
    "tvos-arm64_x86_64-simulator|Info.plist|MinimumOSVersion|17.0|AppleTVSimulator" \
    "macos-arm64_x86_64|Versions/Current/Resources/Info.plist|LSMinimumSystemVersion|15.0|MacOSX"; do
    IFS='|' read -r slice plist_path minimum_os_key minimum_os supported_platform <<< "$entry"
    framework="$OUTPUT_DIR/CNestopiaCore.xcframework/$slice/CNestopiaCore.framework"
    test -f "$framework/Modules/module.modulemap" || {
        echo "XCFramework slice has no namespaced module map: $framework" >&2
        exit 1
    }
    plist="$framework/$plist_path"
    test -f "$plist" || {
        echo "XCFramework slice has no framework Info.plist: $framework" >&2
        exit 1
    }
    test "$(plutil -extract "$minimum_os_key" raw -o - "$plist")" = "$minimum_os" || {
        echo "XCFramework slice has the wrong minimum OS version: $framework" >&2
        exit 1
    }
    test "$(plutil -extract CFBundleSupportedPlatforms.0 raw -o - "$plist")" = "$supported_platform" || {
        echo "XCFramework slice has the wrong CFBundleSupportedPlatforms: $framework" >&2
        exit 1
    }
done

MACOS_FRAMEWORK="$OUTPUT_DIR/CNestopiaCore.xcframework/macos-arm64_x86_64/CNestopiaCore.framework"
test -f "$MACOS_FRAMEWORK/Versions/Current/Resources/Info.plist" || {
    echo "The macOS framework must use a versioned bundle layout." >&2
    exit 1
}
test ! -e "$MACOS_FRAMEWORK/Info.plist" || {
    echo "The macOS framework must not use a shallow Info.plist." >&2
    exit 1
}

{
    echo "nestopia prebuilt CNestopiaCore"
    echo
    echo "wrapper commit:  $(git -C "$REPO_ROOT" rev-parse HEAD)"
    echo "upstream commit: $(git -C "$REPO_ROOT/nestopia" rev-parse HEAD)"
    echo "upstream source: https://github.com/0ldsk00l/nestopia"
    echo
    echo "Nestopia and this linked wrapper are distributed under GPL-2.0-or-later."
    echo "Corresponding source consists of the upstream commit and wrapper commit above."
} > "$OUTPUT_DIR/SOURCES.txt"

cp "$REPO_ROOT/LICENSE" "$OUTPUT_DIR/CNestopiaCore.xcframework/LICENSE"
cp "$OUTPUT_DIR/SOURCES.txt" "$OUTPUT_DIR/CNestopiaCore.xcframework/SOURCES.txt"

(
    cd "$OUTPUT_DIR"
    ditto -c -k --sequesterRsrc --keepParent CNestopiaCore.xcframework CNestopiaCore.xcframework.zip
)
unzip -p "$OUTPUT_DIR/CNestopiaCore.xcframework.zip" CNestopiaCore.xcframework/LICENSE | cmp "$REPO_ROOT/LICENSE" -

export NESTOPIA_BUILD_FROM_SOURCE=1
swift package --package-path "$REPO_ROOT" compute-checksum \
    "$OUTPUT_DIR/CNestopiaCore.xcframework.zip" > "$OUTPUT_DIR/checksum.txt"

echo "Created CNestopiaCore.xcframework.zip"
echo "Checksum: $(cat "$OUTPUT_DIR/checksum.txt")"
