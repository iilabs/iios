#!/usr/bin/env bash
set -euo pipefail

SQUID_BIN=$(command -v squid)
SSL_CRTD=${SSL_CRTD:-/usr/lib64/squid/security_file_certgen}

create_dirs() {
  mkdir -p "$SQUID_LOG_DIR" "$SQUID_CACHE_DIR" "$SQUID_SSL_DB_DIR"
  chown -R "$SQUID_USER":"$SQUID_USER" "$SQUID_LOG_DIR" "$SQUID_CACHE_DIR"
}

init_cache() {
  if [ ! -d "$SQUID_CACHE_DIR/00" ]; then
    echo "Initializing squid cache store..."
    "$SQUID_BIN" -f /etc/squid/squid.conf -z
  fi
}

init_ssl_db() {
  if [ -x "$SSL_CRTD" ]; then
    if [ ! -d "$SQUID_SSL_DB_DIR" ] || [ ! -f "$SQUID_SSL_DB_DIR"/ssl_crtd.id ]; then
      echo "Initializing ssl_crtd database..."
      rm -rf "$SQUID_SSL_DB_DIR"
      "$SSL_CRTD" -c -s "$SQUID_SSL_DB_DIR" -M 64MB
      chown -R "$SQUID_USER":"$SQUID_USER" "$SQUID_SSL_DB_DIR"
    fi
  else
    echo "WARN: ssl_crtd binary not found at $SSL_CRTD; TLS bump may fail." >&2
  fi
}

create_dirs
init_ssl_db
init_cache

echo "Starting squid..."
exec "$SQUID_BIN" -f /etc/squid/squid.conf -NYCd 1 "$@"
