# iios Agent Readme

## Purpose

Create **read–write bootable USB systems** for demonstrations, education, and persistent use.  
Typical live installers use **read-only ISO images**; our goal is to make bootable media that can:

- Boot directly on EFI systems  
- Retain changes, files, and configurations  
- Operate offline for teaching or deployment

The resulting USB will contain:
- An **EFI/FAT boot partition**  
- A **Btrfs system partition** supporting snapshots and subvolumes  
- Local caches for packages, containers, and other artifacts

Each USB should be able to rebuild or clone another USB entirely offline.

---

## Current Foundation

Work is based on **Bluefin / uBlue**, which combine:
- **bootc** for OCI-based image creation  
- **Flatpak**, **Homebrew**, **ostree**, and **containers** as layered software sources

Bluefin builds ISOs for installation, but those are read-only and slow to iterate.  
We want a writable system image that can update quickly using local caches.

---

## Plan

1. **Cache every software source** we depend on:
   - Flatpak remotes  
   - Container registries  
   - OSTree commits  
   - Homebrew formulas  

2. **Curate package lists** (`flatpaks.txt`, `containers.txt`, `brew.txt`, etc.)  
   Each build process should:
   - Pre-populate caches  
   - Support fully offline installation  
   - Mount or reference these caches during image creation  

3. **Optimize reuse via Btrfs subvolumes**  
   Store frequently used layers or volumes as Btrfs snapshots.  
   These can be imported and mounted rather than reinstalled.

4. **Assemble bootable images**
   - Use cached artifacts during image creation  
   - Output a writable USB image with persistent system and user data  

---

## Current Focus — Building the Cache

The `./cache/` directory will contain:

```
cache/
├── flatpaks/
├── containers/
├── ostree/
└── brew/
```


Each sub-cache stores artifacts for its respective package system.

Goals:
- Speed up local builds by avoiding repeated downloads  
- Allow offline installation and replication  
- Provide mountable, ready-to-use software environments

---

## Cache Types

### Flatpak
- Requires both a **repo** (sideload cache) and an **installation** folder  
- The booted OS can mount this as an additional Flatpak installation for instant access  
- We’ll maintain scripts to rebuild, refresh, and mount these caches

### OCI Images stored as Podman Container Images
- Likely maps directly to `/var/lib/containers`  
- Podman or Buildah can import/export OCI images from this cache

### OSTree
- Built from OCI images and “pushed” into an ostree repository  
- Needs clarification between a “repo” and an “install”  
- Target: make OSTree layers mountable and reusable offline

### Brew
- Uses a Brewfile to create the cache
- Need to test which integrates best with bootc and ostree images  
- Plan: cache downloaded bottles and reuse across builds

### Squid
- Prepare an offline-friendly HTTP proxy cache (e.g., `/var/spool/squid`) that can be snapshotted and shipped with the USB  
- Requires investigation into running Squid rootless vs. packaging prebuilt cache directories  
- Goal: leverage Squid when rebuilding systems so upstream repos resolve locally first

### RPM Repositories
- Mirror required RPMs plus metadata into a local repo structure under `cache/rpms`  
- Decide whether to rely on `dnf download`, `reposync`, or `rpm-ostree` mirroring  
- Target: allow rpm-based installers to run fully offline using the mirrored repo

---

## Next Steps

1. **Flatpak**
   - Finalize `flatpak-ids.txt`
   - Generate `flatpak-refs.txt` via `flatpak info --show-ref`
   - Build sideload repo and portable installation under `cache/flatpaks`

2. **Containers**
   - Collect required OCI images into `cache/containers`
   - Provide import/export helpers for Podman/Buildah

3. **OSTree**
   - Experiment with exporting from bootc builds into `cache/ostree`
   - Define `push` workflow and how installations consume it

4. **Brew**
   - Confirm whether Bluefin supports system-level Homebrew
   - Add caching for bottles and formulas in `cache/brew`

5. **Squid**
   - Prototype building a reusable Squid cache directory that can be distributed  
   - Explore rsync/btrfs snapshot workflows for updating the cache offline

6. **RPM Mirrors**
   - Identify core packages that should be mirrored into `cache/rpms`  
   - Automate metadata refresh (`createrepo_c`, etc.) for consistency with upstream

7. **Automation**
   - Write `build-cache.sh` to regenerate all caches  
   - Write `rehydrate.sh` to mount them on a booted system  
   - Add Makefile targets or agent tasks for both

8. **Documentation**
   - Add diagrams showing how caches map into the live filesystem  
   - Document how to rebuild a USB entirely offline

---

## Summary

We are building a **self-contained, writable, bootable system** that can:
- Run entirely from a USB drive  
- Persist user data and software  
- Be reproduced offline from local caches  

This enables faster iteration, reproducible demos, and resilient field deployments.
