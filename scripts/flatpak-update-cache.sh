#!/usr/bin/env bash
# Usage: update-usb-cache-from-ids.sh <cache_dir> [flatpaks.txt] [REMOTE]
# Builds/refreshes sideload repo at <cache_dir>/repo using ids in flatpaks.txt
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

CACHE="${1:?cache/flatpak dir}"
CACHE="${CACHE%/}"
REMOTE="${3:-flathub}"

DEFAULT_REF_FILE="$CACHE/flatpak-refs.txt"
FALLBACK_REF_FILE="$REPO_ROOT/flatpak-refs.txt"

if [ $# -ge 2 ]; then
    REF_FILE="$2"
elif [ -f "$DEFAULT_REF_FILE" ]; then
    REF_FILE="$DEFAULT_REF_FILE"
elif [ -f "$FALLBACK_REF_FILE" ]; then
    REF_FILE="$FALLBACK_REF_FILE"
else
    echo "ERROR: no ref list supplied and none found at $DEFAULT_REF_FILE or $FALLBACK_REF_FILE" >&2
    exit 1
fi

REPO="$CACHE/repo"
mkdir -p "$REPO"

# Collect refs into an array so each ref is passed as its own argument.
mapfile -t REF_LINES <"$REF_FILE"

REFS=()
for ref in "${REF_LINES[@]}"; do
    # ignore blank lines and comments
    [[ -z "${ref//[[:space:]]/}" || $ref =~ ^[[:space:]]*# ]] && continue
    REFS+=("$ref")
done

if [ ${#REFS[@]} -eq 0 ]; then
    echo "ERROR: no refs to mirror (checked $REF_FILE)" >&2
    exit 1
fi

# Init repo and mirror objects
ostree --repo="$REPO" init --mode=archive-z2 2>/dev/null || true
ostree --repo="$REPO" config set core.gpg-verify false
ostree --repo="$REPO" remote delete "$REMOTE" 2>/dev/null || true
ostree --repo="$REPO" remote add --no-gpg-verify "$REMOTE" https://dl.flathub.org/repo/
ostree --repo="$REPO" pull --mirror "$REMOTE" "${REFS[@]}"
flatpak build-update-repo --generate-static-deltas "$REPO"

echo "OK: $REPO"
