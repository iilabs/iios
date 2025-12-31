# Squid Proxy Plan

## Goals
- Provide an offline-ready HTTP/HTTPS caching proxy for container builds and package downloads.
- Run Squid rootlessly via Podman so the cache can be prepared on developer machines without elevated privileges.
- Persist cached artifacts inside `cache/squid` so the USB image can ship a warm cache.
- Surface proxy environment variables and trust bundles that builders can reuse with minimal configuration.

## Configuration
- Build a custom image via `squid/Containerfile` (Fedora base, `squid` + `openssl`) so TLS bumping is available. `scripts/squid-compose.sh up` runs `podman-compose ... up --build`, producing `localhost/iios-squid:latest` by default. Override the image with `SQUID_IMAGE` if needed.
- The container runs in user space (`podman compose up`) with host port `53128` mapped to container `3128`. Rootless Podman provides networking; no elevated privileges required.
- Bind-mount `squid/squid.conf` (read-only), `cache/squid/{var,log,ca}` (state + certificates) into the container using `:Z` for SELinux-friendly labeling.
- Automation drops `cache/squid/env.sh` containing `HTTP_PROXY`, `HTTPS_PROXY`, and `NO_PROXY` so builds can `source` it before running `podman build`, `dnf`, `curl`, etc.

## Integration with Container Builds
- Provide a helper script (future work) that starts the rootless Squid container, writes proxy variables into a temporary file, and outputs command-line snippets:
  - `HTTP_PROXY=http://127.0.0.1:53128`
  - `HTTPS_PROXY=http://127.0.0.1:53128`
  - `NO_PROXY=localhost,127.0.0.1,.local`
- Encourage using `podman build --http-proxy` while the environment variables are set. Podman forwards the proxy to buildah so base-image downloads use the cache.
- For offline USB usage, bind-mount the persistent cache directories into the Squid container, start it at boot, and export the proxy variables system-wide (e.g., via `/etc/profile.d/squid-proxy.sh`).

## Directory Layout
```
cache/
└── squid/
    ├── log/                # /var/log/squid (bind mounted, rotated on host)
    ├── var/                # /var/spool/squid object cache + ssl_db
    ├── ca/                 # squid-ca.pem / squid-ca.key (generated automatically)
    └── env.sh              # exported HTTP_PROXY/HTTPS_PROXY/NO_PROXY values

squid/
├── Containerfile           # custom Fedora-based Squid image with TLS bump enabled
├── compose.yaml            # podman-compose definition
├── entrypoint.sh           # initializes cache + ssl_db before starting squid
└── squid.conf              # version-controlled configuration mounted into the container
```

## TLS Interception & CA Handling
- `scripts/squid-compose.sh up` generates a self-signed root (`cache/squid/ca/squid-ca.pem` + `.key`) with OpenSSL, initializes Squid’s `security_file_certgen` database, and mounts the CA into the container at `/etc/squid/certs`.
- `squid/squid.conf` enables `ssl_bump` on port 3128, points `sslcrtd_program` at `/usr/lib64/squid/security_file_certgen`, and bumps all HTTPS origins by default. Adjust ACLs if any domains should be spliced.
- Clients must trust the generated CA: copy `cache/squid/ca/squid-ca.pem` into the system trust store (`/etc/pki/ca-trust/source/anchors/` + `update-ca-trust` on Fedora, `/usr/local/share/ca-certificates/` + `update-ca-certificates` on Debian) or supply it per-tool (`REQUESTS_CA_BUNDLE`, `SSL_CERT_FILE`, `--cacert`).
- `scripts/squid-test.sh` sources the proxy env, ensures the CA exists (`squid-compose.sh ca`), fetches a URL with `curl --cacert`, and tails `/var/log/squid/store.log` to confirm cache hits.

## Configuration Considerations for Large Artifacts
- **`maximum_object_size` / `maximum_object_size_in_memory`**: bump disk object limits to accommodate multi-gigabyte RPM/OCI layers (e.g., `maximum_object_size 2048 MB`) while keeping in-memory objects small (e.g., `1 MB`).
- **`cache_mem`**: allocate 256–512 MB by default for rootless runs; scale up on hosts with more RAM to improve hit rates for manifest JSON and metadata.
- **`cache_dir`**: choose a backend such as `aufs` or `rock` with a size quota matching the USB budget (20–50 GB). Point it at `cache/squid/var` so the cache survives container restarts.
- **`collapsed_forwarding on`**: ensures simultaneous requests for the same large file collapse into a single download.
- **`refresh_pattern` overrides**: extend freshness for RPM/Flatpak registries to avoid revalidating large objects too frequently while respecting upstream change intervals.
- **`store_dir_select_algorithm least-load`**: useful if we shard cache directories for better throughput on large binaries.
- **TLS knobs**: configure `tls_outgoing_options` and `sslproxy_cert_error` to match our generated CA and avoid handshake failures when mirroring HTTPS content.
- **Logging/rotation**: tighten `logfile_rotate` to prevent logs from exhausting flash storage during large transfer sessions.

Add these directives to `squid/squid.conf` with comments noting the rationale so automation (or future templating) can adjust values based on available disk/RAM and desired retention.

## Outstanding Questions
- Which upstream Squid OCI image offers the best support for SSL bumping and rootless operation without additional tweaks?
- Can we pre-initialize `/var/spool/squid` with `squid -z` in a rootless container, or do we need a one-time privileged run?
- How large should we allow the cache to grow on the USB, and do we control it via `cache_mem`/`maximum_object_size` settings?
- What tooling should automatically regenerate the CA and distribute it to container build contexts?

## Next Steps
1. Prototype a rootless Podman deployment using a candidate Squid image and confirm cache persistence within `cache/squid`.
2. Validate HTTPS interception and CA injection inside a sample Fedora container build.
3. Automate proxy environment variable generation and document usage in `cache.md` once the workflow stabilizes.
4. Integrate Squid start/stop tasks into future `build-cache.sh` and `rehydrate.sh` scripts.
