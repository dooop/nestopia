#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <aar> <apk> <comma-separated-abis>" >&2
    exit 2
fi

AAR="$1"
APK="$2"
IFS=',' read -r -a ABIS <<< "$3"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

test -f "$AAR" || { echo "Missing AAR: $AAR" >&2; exit 1; }
test -f "$APK" || { echo "Missing APK: $APK" >&2; exit 1; }
unzip -q "$AAR" -d "$WORK_DIR/aar"
unzip -q "$APK" -d "$WORK_DIR/apk"

require_file() {
    test -f "$1" || { echo "Missing artifact entry: $1" >&2; exit 1; }
}

require_file "$WORK_DIR/aar/AndroidManifest.xml"
require_file "$WORK_DIR/aar/classes.jar"
require_file "$WORK_DIR/aar/assets/NstDatabase.xml"
require_file "$WORK_DIR/aar/assets/licenses/GPL-2.0-or-later.txt"
require_file "$WORK_DIR/apk/assets/licenses/GPL-2.0-or-later.txt"
cmp LICENSE "$WORK_DIR/aar/assets/licenses/GPL-2.0-or-later.txt"
cmp LICENSE "$WORK_DIR/apk/assets/licenses/GPL-2.0-or-later.txt"

if grep -Eq '<(application|uses-feature|uses-permission)([[:space:]>])' "$WORK_DIR/aar/AndroidManifest.xml"; then
    echo "The library manifest must not add application, feature, or permission declarations." >&2
    exit 1
fi

CLASSES="$(jar tf "$WORK_DIR/aar/classes.jar")"
for class in \
    net/sourceforge/nestopia/NestopiaKt.class \
    net/sourceforge/nestopia/NestopiaConfiguration.class \
    net/sourceforge/nestopia/NestopiaEngine.class \
    net/sourceforge/nestopia/NestopiaViewKt.class \
    net/sourceforge/nestopia/internal/NativeNestopia.class; do
    grep -qx "$class" <<< "$CLASSES" || { echo "Missing class: $class" >&2; exit 1; }
done

EXPECTED_ABIS="$(printf '%s\n' "${ABIS[@]}" | sort)"
AAR_ABIS="$(find "$WORK_DIR/aar/jni" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)"
APK_ABIS="$(find "$WORK_DIR/apk/lib" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)"
test "$AAR_ABIS" = "$EXPECTED_ABIS" || { echo "Unexpected AAR ABIs: $AAR_ABIS" >&2; exit 1; }
test "$APK_ABIS" = "$EXPECTED_ABIS" || { echo "Unexpected APK ABIs: $APK_ABIS" >&2; exit 1; }

READELF="${READELF:-}"
if [ -z "$READELF" ] && [ -n "${ANDROID_NDK_ROOT:-}" ]; then
    READELF="$(find "$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt" -path '*/bin/llvm-readelf' -print -quit)"
fi
test -x "$READELF" || { echo "Set READELF or ANDROID_NDK_ROOT." >&2; exit 1; }

for abi in "${ABIS[@]}"; do
    require_file "$WORK_DIR/aar/jni/$abi/libnestopia.so"
    require_file "$WORK_DIR/apk/lib/$abi/libnestopia.so"
    while read -r alignment; do
        test "$((alignment))" -ge "$((0x4000))" || {
            echo "libnestopia.so for $abi has LOAD alignment $alignment; 0x4000 is required." >&2
            exit 1
        }
    done < <("$READELF" -lW "$WORK_DIR/aar/jni/$abi/libnestopia.so" | awk '$1 == "LOAD" { print $NF }')
done

echo "Verified AAR, APK, licenses, runtime database, Kotlin/JNI API, ABIs, and 16 KB alignment."
