#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <output.tar.gz> <archive-root-name>" >&2
    exit 2
fi

OUTPUT_ARCHIVE="$1"
ARCHIVE_ROOT="$2"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

case "$ARCHIVE_ROOT" in
    ""|*/*|.|..)
        echo "Invalid archive root name: $ARCHIVE_ROOT" >&2
        exit 2
        ;;
esac

mkdir -p "$(dirname "$OUTPUT_ARCHIVE")" "$WORK_DIR/$ARCHIVE_ROOT/nestopia"
git -C "$REPO_ROOT" archive HEAD | tar -x -C "$WORK_DIR/$ARCHIVE_ROOT"
git -C "$REPO_ROOT/nestopia" archive HEAD | tar -x -C "$WORK_DIR/$ARCHIVE_ROOT/nestopia"
tar -czf "$OUTPUT_ARCHIVE" -C "$WORK_DIR" "$ARCHIVE_ROOT"

echo "Created complete corresponding source: $OUTPUT_ARCHIVE"
