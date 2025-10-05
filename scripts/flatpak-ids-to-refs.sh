#!/usr/bin/env bash
# Usage: flatpak-ids-to-refs.sh <flatpak-ids.txt> [--system|--user] [REMOTE]
# Default scope: --system  |  Default REMOTE: flathub
set -euo pipefail
FLATPAK_ID_FILE="${1:?path required}"; SCOPE="${2:---system}"; REMOTE="${3:-flathub}"
[ -f "$FLATPAK_ID_FILE" ] || { echo "missing $FLATPAK_ID_FILE" >&2; exit 1; }

# echo canonical refs, warn on misses
while IFS= read -r id; do
  [[ -z "$id" || "$id" =~ ^[[:space:]]*# ]] && continue
  flatpak info $SCOPE --show-ref "$id" 2>/dev/null \
    || echo "warn: $id not found on $REMOTE ($SCOPE)" >&2
done < "$FLATPAK_ID_FILE" | awk 'NF'
