#!/usr/bin/env bash
set -euo pipefail

# The Apple package ships NstDatabase.xml as a regular file so that binary-mode
# builds and SwiftPM consumers never need the nestopia/ submodule. Refresh the
# vendored copy with this script whenever the submodule is bumped; CI verifies
# that it stays byte-identical to upstream.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM="$REPO_ROOT/nestopia/NstDatabase.xml"
VENDORED="$REPO_ROOT/swift/Sources/Nestopia/Resources/NstDatabase.xml"

MODE="${1:-sync}"
case "$MODE" in
    sync|--check) ;;
    *)
        echo "Usage: $0 [--check]" >&2
        exit 2
        ;;
esac

if [ ! -f "$UPSTREAM" ]; then
    echo "Missing nestopia/NstDatabase.xml; run: git submodule update --init" >&2
    exit 2
fi

if [ "$MODE" = "--check" ]; then
    if ! cmp -s "$UPSTREAM" "$VENDORED"; then
        echo "Vendored ${VENDORED#"$REPO_ROOT/"} differs from the submodule." >&2
        echo "Run scripts/sync-vendored-resources.sh and commit the result." >&2
        exit 1
    fi
    echo "Vendored resources match the nestopia/ submodule."
    exit 0
fi

cp "$UPSTREAM" "$VENDORED"
echo "Synced ${VENDORED#"$REPO_ROOT/"} from the nestopia/ submodule."
