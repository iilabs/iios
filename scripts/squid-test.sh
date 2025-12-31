#!/usr/bin/env bash
# Usage: squid-test.sh <URL>
# Requires squid-compose.sh up to be running. Fetches URL via proxy and checks cache entries.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CACHE_ROOT="$REPO_ROOT/cache/squid"
SQUID_COMPOSE="$SCRIPT_DIR/squid-compose.sh"
CONTAINER_NAME="squid-cache"
URL="${1:?URL required}"

ENV_FILE="$CACHE_ROOT/env.sh"
CA_CERT="$CACHE_ROOT/ca/squid-ca.pem"

if [ ! -f "$ENV_FILE" ]; then
    mkdir -p "$CACHE_ROOT"
    cat >"$ENV_FILE" <<'ENV'
export HTTP_PROXY=${HTTP_PROXY:-http://127.0.0.1:53128}
export HTTPS_PROXY=${HTTPS_PROXY:-http://127.0.0.1:53128}
export NO_PROXY=${NO_PROXY:-localhost,127.0.0.1,.local}
ENV
    chmod 600 "$ENV_FILE" || true
    echo "INFO: created default proxy env at $ENV_FILE" >&2
fi

# Ensure the Squid CA exists so curl trusts bumped certificates.
if [ ! -f "$CA_CERT" ]; then
    "$SQUID_COMPOSE" ca
fi

[ -f "$CA_CERT" ] || { echo "ERROR: missing Squid CA at $CA_CERT" >&2; exit 1; }

# shellcheck disable=SC1090
source "$ENV_FILE"

echo "==> Fetching $URL via proxy"
if command -v curl >/dev/null 2>&1; then
    curl --fail --proxy "$HTTP_PROXY" --cacert "$CA_CERT" "$URL" >/dev/null
else
    echo "WARN: curl not found; skipping fetch" >&2
fi

echo "==> Checking Squid cache metadata"
if command -v podman >/dev/null 2>&1; then
    if podman exec "$CONTAINER_NAME" sh -c "command -v squidclient >/dev/null" 2>/dev/null; then
        podman exec "$CONTAINER_NAME" squidclient -p 3128 cache_object://localhost/store 2>/dev/null | \
            grep -E "^KEY|^URL" || echo "WARN: unable to read cache index" >&2
    else
        echo "INFO: squidclient not present in image; inspect logs instead." >&2
    fi
    echo "==> Inspecting store log for cache hits"
    podman exec "$CONTAINER_NAME" tail -n 50 /var/log/squid/store.log || true
else
    echo "ERROR: podman not installed" >&2
    exit 1
fi

echo "OK: Squid cache test complete"
