#!/usr/bin/env bash
# Usage: update-usb-cache-from-ids.sh <cache_dir> [flatpaks.txt] [REMOTE]
# Builds/refreshes sideload repo at <cache_dir>/repo using ids in flatpaks.txt
set -euo pipefail
CACHE="${1:?cache/flatpak dir}"; REF_FILE="${2:-$1/flatpak-refs.txt}"; REMOTE="${3:-flathub}"
REPO="$CACHE/repo"
mkdir -p "$REPO"

# REFS needs to be a single line to pass to ostree pull
REFS=$(cat $REF_FILE | tr '\n' ' ')

# Init repo and mirror objects
ostree --repo="$REPO" init --mode=archive-z2 2>/dev/null || true
ostree --repo="$REPO" config set core.gpg-verify false
ostree --repo="$REPO" remote delete "$REMOTE" 2>/dev/null || true
ostree --repo="$REPO" remote add --no-gpg-verify "$REMOTE" https://dl.flathub.org/repo/
ostree --repo="$REPO" pull --mirror "$REMOTE" "${REFS[@]}"
flatpak build-update-repo --generate-static-deltas "$REPO"

echo "OK: $REPO"
