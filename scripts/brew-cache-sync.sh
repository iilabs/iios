#!/usr/bin/env bash
# Usage: brew-cache-sync.sh [cache_dir] [Brewfile]
# Populates a reusable Homebrew cache for offline installs.
set -xeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

CACHE_DIR="${1:-$REPO_ROOT/cache}"
CACHE_DIR="${CACHE_DIR%/}"

if [ $# -ge 2 ]; then
    BREWFILE="$2"
elif [ -f "$CACHE_DIR/Brewfile" ]; then
    BREWFILE="$CACHE_DIR/Brewfile"
else
    BREWFILE="$REPO_ROOT/Brewfile"
fi

if [ ! -f "$BREWFILE" ]; then
    echo "ERROR: Brewfile not found at $BREWFILE" >&2
    exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
    echo "ERROR: Homebrew (brew) command not found" >&2
    exit 1
fi

BREW_CACHE_ROOT="$CACHE_DIR/brew"
DOWNLOAD_CACHE="$BREW_CACHE_ROOT/cache"
LOCK_DEST="$BREW_CACHE_ROOT/Brewfile.lock.json"

mkdir -p "$DOWNLOAD_CACHE"

export HOMEBREW_CACHE="$DOWNLOAD_CACHE"
export HOMEBREW_NO_INSTALL_CLEANUP=1

# Gather dependencies from the Brewfile using brew bundle list.
export HOMEBREW_BUNDLE_FILE="$BREWFILE"

readarray -t FORMULAE < <(brew bundle list --file "$BREWFILE" --formula 2>/dev/null || true)
readarray -t CASKS < <(brew bundle list --file "$BREWFILE" --cask 2>/dev/null || true)

echo "==> Caching Homebrew artifacts defined in $BREWFILE"

if [ ${#FORMULAE[@]} -gt 0 ]; then
    echo "    Fetching formula bottles: ${FORMULAE[*]}"
    brew fetch --retry "${FORMULAE[@]}"
fi

if [ ${#CASKS[@]} -gt 0 ]; then
    echo "    Fetching casks: ${CASKS[*]}"
    brew fetch --retry --cask "${CASKS[@]}"
fi

if [ ${#FORMULAE[@]} -eq 0 ] && [ ${#CASKS[@]} -eq 0 ]; then
    echo "WARN: no formulae or casks discovered in $BREWFILE" >&2
fi

# Generate a lockfile so versions can be reused offline when supported.
LOCK_SOURCE="${BREWFILE}.lock.json"
if brew bundle --help 2>/dev/null | grep -q "bundle lock"; then
    if brew bundle lock --file "$BREWFILE" --quiet >/dev/null 2>&1; then
        if [ -f "$LOCK_SOURCE" ]; then
            cp "$LOCK_SOURCE" "$LOCK_DEST"
        fi
    else
        echo "WARN: brew bundle lock failed; skipping lockfile" >&2
    fi
else
    echo "WARN: this version of brew bundle does not support 'lock'; skipping lockfile" >&2
fi

echo "==> Cached downloads stored in $DOWNLOAD_CACHE"
if [ -f "$LOCK_DEST" ]; then
    echo "    Lockfile: $LOCK_DEST"
fi

echo "OK: brew cache ready"
