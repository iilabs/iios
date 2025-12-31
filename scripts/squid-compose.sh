#!/usr/bin/env bash
# Wrapper for podman compose actions using ./squid/compose.yaml.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SQUID_DIR="$REPO_ROOT/squid"
COMPOSE_FILE="$SQUID_DIR/compose.yaml"
CACHE_ROOT="$REPO_ROOT/cache/squid"
PODMAN_COMPOSE_WARNING_LOGS=false # see podman-compose(1)

usage() {
    echo "Usage: $0 <up|down|ps|logs|ca> [podman-compose args]" >&2
    exit 1
}

ensure_ca() {
    local ca_dir="$CACHE_ROOT/ca"
    local ca_key="$ca_dir/squid-ca.key"
    local ca_cert="$ca_dir/squid-ca.pem"
    local ca_der="$ca_dir/squid-ca.der"
    if [ -f "$ca_key" ] && [ -f "$ca_cert" ]; then
        return
    fi
    command -v openssl >/dev/null 2>&1 || { echo "ERROR: openssl required to generate proxy CA" >&2; exit 1; }
    mkdir -p "$ca_dir"

    tmp_key="$ca_key.$$"
    tmp_cert="$ca_cert.$$"

    openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes -batch \
        -subj "/CN=iios Squid Cache CA" \
        -keyout "$tmp_key" \
        -out "$tmp_cert"

    mv "$tmp_key" "$ca_key"
    mv "$tmp_cert" "$ca_cert"
    chmod 600 "$ca_key"
    chmod 644 "$ca_cert"

    openssl x509 -in "$ca_cert" -outform DER -out "$ca_der"

    echo "INFO: Generated Squid CA at $ca_cert" >&2
}

[ -f "$COMPOSE_FILE" ] || { echo "ERROR: missing $COMPOSE_FILE" >&2; exit 1; }

CMD="${1:-}"
shift || true

case "$CMD" in
    up)
        ensure_ca
        mkdir -p "$CACHE_ROOT/var" "$CACHE_ROOT/log"
        chmod 0777 "$CACHE_ROOT/var" "$CACHE_ROOT/log" || true
        rm -rf "$CACHE_ROOT/var/ssl_db"
        cat >"$CACHE_ROOT/env.sh" <<'ENV'
export HTTP_PROXY=${HTTP_PROXY:-http://127.0.0.1:53128}
export HTTPS_PROXY=${HTTPS_PROXY:-http://127.0.0.1:53128}
export NO_PROXY=${NO_PROXY:-localhost,127.0.0.1,.local}
ENV
        chmod 600 "$CACHE_ROOT/env.sh"
        podman-compose -f "$COMPOSE_FILE" up -d --build "$@"
        ;;
    down)
        podman-compose -f "$COMPOSE_FILE" down "$@"
        ;;
    ps)
        podman-compose -f "$COMPOSE_FILE" ps "$@"
        ;;
    logs)
        podman-compose -f "$COMPOSE_FILE" logs "$@"
        ;;
    ca)
        ensure_ca
        ;;
    ""|-h|--help)
        usage
        ;;
    *)
        echo "ERROR: unknown command '$CMD'" >&2
        usage
        ;;
 esac
