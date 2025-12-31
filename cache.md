# Cache Playbook

Guidelines for creating, updating, and consuming each cache managed under `./cache/`. Defaults live in the repository root and can be overridden by placing files with the same name inside `cache/`.

---

## Flatpak Cache
- **Populate**: `scripts/flatpak-update-usb-cache.sh <cache_dir>` (defaults to `./cache/flatpak`). The script reads `flatpak-refs.txt` (override with `cache/flatpak-refs.txt`) and mirrors the refs into `cache/flatpak/repo`.
- **Update**: Re-run the script; it re-pulls referenced commits and regenerates static deltas in place.
- **Use on Target**: Mount `cache/flatpak/repo` as a sideload repo (`flatpak --installation=<path> remote-add --if-not-exists sideload file://...`) or copy it into `/var/lib/flatpak/repo`. If a portable installation exists in `cache/flatpak/install`, point `flatpak --installation` at that directory for instant availability.

## Container Cache (Podman)
- **Populate**: `scripts/podman-cache-sync.sh [cache_dir] [oci-images.txt]`. Defaults to `cache/containers` and reads `oci-images.txt` (override with `cache/oci-images.txt`). Images are pulled rootlessly with Podman and stored under `cache/containers/storage` (graph root) and `cache/containers/runroot`.
- **Update**: Re-run the script after editing the image list; Podman skips existing layers. Remove legacy `*.tar` archives in `cache/containers/` once the new storage layout is in place.
- **Use on Target**: Bind-mount `cache/containers/storage` to `/var/lib/containers/storage` (and `runroot` to `/run/containers`) or invoke Podman with `--root`/`--runroot` pointing at those paths. The system can then run containers without pulling images.

## Homebrew Cache
- **Populate**: `scripts/brew-cache-sync.sh [cache_dir] [Brewfile]`. Defaults to `cache/brew` and the root `Brewfile` (override with `cache/Brewfile`). The script sets `HOMEBREW_CACHE` to `cache/brew/cache`, fetches bottles/casks, and copies any generated `Brewfile.lock.json` into `cache/brew/`.
- **Update**: Adjust the Brewfile, then rerun the script. `brew fetch` is idempotent; cached bottles stay untouched.
- **Use on Target**: Set `HOMEBREW_CACHE=/path/to/cache/brew/cache` before running `brew bundle install --file <Brewfile>`. Include the lockfile to pin versions when available.

## DNF Cache
- **Populate**: `just dnf-prefetch` (or run [`scripts/dnf-prefetch.sh`](./scripts/dnf-prefetch.sh)) to launch the base image with `cache/dnf` and `cache/rpm-ostree` mounted. The helper installs the appropriate DNF plugins, runs `dnf makecache`, and mirrors enabled repositories with `dnf reposync` so cached RPMs and metadata land in the shared directory.
- **Update**: Re-run the script whenever you need newer packages; it refreshes metadata and downloads changed RPMs in place.
- **Use on Target**: Bind-mount `cache/dnf` to `/var/cache/dnf` (or set `cachedir` in `/etc/dnf/dnf.conf`) before invoking `dnf`/`dnf5`. Mount `cache/rpm-ostree` to `/var/cache/rpm-ostree` for layering operations. Copy both directories onto removable media to share the cache across systems.

## RPM Repository Cache (Legacy idea)
*The new DNF cache workflow above already mirrors enabled repositories with `dnf reposync`. Keep this section only if you need a handcrafted repo layout or additional metadata customization.*
- **Populate**: Mirror required RPMs into `cache/rpms` using tools like `dnf download`, `reposync`, or `rpm-ostree` pulls, then run `createrepo_c` to generate metadata.
- **Update**: Periodically re-run the mirroring tool and metadata regeneration to pick up security updates.
- **Use on Target**: Configure `dnf`/`rpm-ostree` with a file-based repo pointing at `cache/rpms`, or bind-mount the directory into `/var/cache/dnf` so that installers consume the local mirror.

---

## General Notes
- Cache scripts avoid root requirements where possible. For caches that must be built as root (e.g., Squid), prefer exporting once on a trusted host and distributing the resulting directory.
- Overrides in `cache/` allow per-device customization without touching tracked defaults.
- Treat caches as immutable artifacts when copying to USB media to ensure deterministic offline rebuilds.
