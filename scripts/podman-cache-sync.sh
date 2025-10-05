#!/usr/bin/env bash
# Usage: podman-cache-sync.sh [cache_dir] [images_list]
# Populates a Podman storage root with the requested OCI images so the
# resulting directory can later be mounted at /var/lib/containers.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

CACHE_DIR="${1:-$REPO_ROOT/cache}"
CACHE_DIR="${CACHE_DIR%/}"

if [ $# -ge 2 ]; then
    IMAGE_LIST="$2"
elif [ -f "$CACHE_DIR/oci-images.txt" ]; then
    IMAGE_LIST="$CACHE_DIR/oci-images.txt"
else
    IMAGE_LIST="$REPO_ROOT/oci-images.txt"
fi

if [ ! -f "$IMAGE_LIST" ]; then
    echo "ERROR: image list not found at $IMAGE_LIST" >&2
    exit 1
fi

if ! command -v podman >/dev/null 2>&1; then
    echo "ERROR: podman is required but not found in PATH" >&2
    exit 1
fi

CONTAINERS_CACHE="$CACHE_DIR/containers"
GRAPHROOT="$CONTAINERS_CACHE/storage"
RUNROOT="$CONTAINERS_CACHE/runroot"

mkdir -p "$GRAPHROOT" "$RUNROOT"

mapfile -t RAW_IMAGES <"$IMAGE_LIST"
IMAGES=()
for entry in "${RAW_IMAGES[@]}"; do
    [[ -z "${entry//[[:space:]]/}" || $entry =~ ^[[:space:]]*# ]] && continue
    IMAGES+=("$entry")
done

if [ ${#IMAGES[@]} -eq 0 ]; then
    echo "ERROR: no OCI images listed in $IMAGE_LIST" >&2
    exit 1
fi

PODMAN_BASE=(podman --root "$GRAPHROOT" --runroot "$RUNROOT")

for image in "${IMAGES[@]}"; do
    echo "==> Pulling $image"
    "${PODMAN_BASE[@]}" pull --quiet "$image"
done

echo "==> Stored images in $GRAPHROOT"
"${PODMAN_BASE[@]}" images --format '    {{.Repository}}:{{.Tag}} ({{.ID}})'

echo "OK: cached ${#IMAGES[@]} image(s) for reuse via /var/lib/containers"
