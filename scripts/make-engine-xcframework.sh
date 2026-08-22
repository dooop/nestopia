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
    library="$SLICES_DIR/$slice/libCNESCore.a"
    headers="$SLICES_DIR/$slice/Headers"
    test -f "$library" || { echo "Missing slice library: $library" >&2; exit 1; }
    test -f "$headers/nes_engine.h" || { echo "Missing headers: $headers" >&2; exit 1; }
    ARGS+=(-library "$library" -headers "$headers")
done

rm -rf "$OUTPUT_DIR/CNESCore.xcframework" "$OUTPUT_DIR/CNESCore.xcframework.zip"
xcodebuild -create-xcframework "${ARGS[@]}" -output "$OUTPUT_DIR/CNESCore.xcframework"

{
    echo "nes prebuilt CNESCore"
    echo
    echo "wrapper commit:  $(git -C "$REPO_ROOT" rev-parse HEAD)"
    echo "upstream commit: $(git -C "$REPO_ROOT/nestopia" rev-parse HEAD)"
    echo "upstream source: https://github.com/0ldsk00l/nestopia"
    echo
    echo "Nestopia and this linked wrapper are distributed under GPL-2.0-or-later."
    echo "Corresponding source consists of the upstream commit and wrapper commit above."
} > "$OUTPUT_DIR/SOURCES.txt"

cp "$REPO_ROOT/LICENSE" "$OUTPUT_DIR/CNESCore.xcframework/LICENSE"
cp "$OUTPUT_DIR/SOURCES.txt" "$OUTPUT_DIR/CNESCore.xcframework/SOURCES.txt"

(
    cd "$OUTPUT_DIR"
    ditto -c -k --sequesterRsrc --keepParent CNESCore.xcframework CNESCore.xcframework.zip
)
unzip -p "$OUTPUT_DIR/CNESCore.xcframework.zip" CNESCore.xcframework/LICENSE | cmp "$REPO_ROOT/LICENSE" -

export NES_BUILD_FROM_SOURCE=1
swift package --package-path "$REPO_ROOT" compute-checksum \
    "$OUTPUT_DIR/CNESCore.xcframework.zip" > "$OUTPUT_DIR/checksum.txt"

echo "Created CNESCore.xcframework.zip"
echo "Checksum: $(cat "$OUTPUT_DIR/checksum.txt")"
