#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
CACHE_DIR=${CACHE_DIR:-${REPO_ROOT}/cache/dnf}
RPMOSTREE_CACHE_DIR=${RPMOSTREE_CACHE_DIR:-${REPO_ROOT}/cache/rpm-ostree}
CONTAINERFILE=${CONTAINERFILE:-${REPO_ROOT}/Containerfile}
STAGE=${STAGE:-}
IMAGE=${IMAGE:-}

mkdir -p "${CACHE_DIR}" "${RPMOSTREE_CACHE_DIR}"

unset http_proxy HTTP_PROXY https_proxy HTTPS_PROXY no_proxy NO_PROXY

if [[ -z "${IMAGE}" ]]; then
  if [[ ! -f "${CONTAINERFILE}" ]]; then
    echo "error: Containerfile not found at ${CONTAINERFILE}" >&2
    exit 1
  fi
  IMAGE=$(awk -v stage="${STAGE}" '
    BEGIN { target=""; last="" }
    /^FROM[[:space:]]+/ {
      img=$2; alias="";
      for (i=3; i<=NF; ++i) if ($i == "AS" && i+1<=NF) { alias=$(i+1) }
      if (stage != "" && alias != "") {
        if (toupper(stage) == toupper(alias)) { target=img }
      }
      last=img
    }
    END {
      if (stage != "" && target != "") { print target }
      else if (stage != "" && target == "") { print "" }
      else { print last }
    }
  ' "${CONTAINERFILE}")
  if [[ -z "${IMAGE}" ]]; then
    echo "error: unable to resolve image from ${CONTAINERFILE}" >&2
    exit 1
  fi
fi

echo "Using image ${IMAGE} to prefetch DNF caches" >&2

PODMAN_RUN=(
  podman run --rm --network host
  -v "${CACHE_DIR}:/var/cache/dnf:Z"
  -v "${RPMOSTREE_CACHE_DIR}:/var/cache/rpm-ostree:Z"
  "${IMAGE}"
  bash -euo pipefail -c '
    if command -v dnf5 >/dev/null 2>&1; then
      DNF=dnf5
      dnf5 install -y dnf5-plugins >/dev/null
    else
      DNF=dnf
      dnf install -y dnf-plugins-core >/dev/null
    fi
    $DNF -y --setopt=cachedir=/var/cache/dnf makecache
    $DNF -y --setopt=cachedir=/var/cache/dnf reposync --download-metadata --download-path=/var/cache/dnf/repos
  '
)

"${PODMAN_RUN[@]}"

echo "DNF cache populated under ${CACHE_DIR}" >&2
