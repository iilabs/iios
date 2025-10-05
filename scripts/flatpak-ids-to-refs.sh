#!/usr/bin/env bash
# Usage: ids-to-refs.sh <flatpaks.txt> [--system|--user] [REMOTE]
# Default scope: --system  |  Default REMOTE: flathub
set -euo pipefail
TXT="${1:?path required}"; SCOPE="${2:---system}"; REMOTE="${3:-flathub}"
[ -f "$TXT" ] || { echo "missing $TXT" >&2; exit 1; }

# echo canonical refs, warn on misses
while IFS= read -r id; do
  [[ -z "$id" || "$id" =~ ^[[:space:]]*# ]] && continue
  flatpak info $SCOPE --show-ref "$id" 2>/dev/null \
    || echo "warn: $id not found on $REMOTE ($SCOPE)" >&2
done < "$TXT" | awk 'NF'

