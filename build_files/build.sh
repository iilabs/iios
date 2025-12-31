#!/bin/bash

set -ouex pipefail

### Copy system files from OCI layers
echo "[oci-layers] copying system files from upstream OCI layers"
if [[ -d /ctx/system_files/shared ]]; then
    rsync -rvK /ctx/system_files/shared/ /
    echo "[oci-layers] copied common system files"
fi
if [[ -d /ctx/system_files/brew ]]; then
    rsync -rvK /ctx/system_files/brew/ /
    echo "[oci-layers] copied homebrew system files"
fi

### Install packages

# Completely disable negativo17 repo to avoid stale metadata issues
sed -i 's/^enabled=0/enabled=0/' /etc/yum.repos.d/negativo17-fedora-multimedia.repo || true
rm -f /etc/yum.repos.d/negativo17-fedora-multimedia.repo || true

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images

echo "[desktop] installing desktop tools"
dnf5 install -y touchegg

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File
#
echo "[rpm-ostree] installs"
rpm-ostree install \
    xdotool \
    vim \
    micro \
    kitty \
    vmtouch
# mkcert skipped - requires nss-3.117.0 which isn't in repos yet

echo "[podman] enabling service"
systemctl enable podman.socket

# Emacs skipped - all emacs variants now require libgccjit which has
# gcc version mismatch with base image (gcc 15.2.1-5 vs repos 15.2.1-2/3/4)
# Use flatpak org.gnu.emacs instead
# echo "[emacs] installing doom emacs dependencies"
# rpm-ostree install \
#   emacs-gtk+x11 \
#   emacs \
#   git-core \
#   gnutls \
#   make \
#   unzip


# this installs a package from fedora repos
dnf5 install -y tmux

echo "[swift-lang] installing Swift programming language"
rpm-ostree install swift-lang

echo "[busybox-build-deps] installing dependencies for building busybox on glibc"
# glibc-devel already in base image (2.41-11, newer than repos)
# gcc-c++ skipped - same gcc version mismatch issue
rpm-ostree install \
  ncurses-devel \
  kernel-headers

# glibc-static/libxcrypt-static skipped - version mismatch with base image
# echo "[glibc-static] installing for static linking"
# rpm-ostree install \
#   libxcrypt-static \
#   glibc-static

echo "[busybox-build-deps] installing dependencies for building busybox on musl"
# musl-clang skipped (requires clang with gcc-c++ version conflicts)
# musl-gcc is sufficient for building with musl
rpm-ostree install \
  musl-gcc \
  musl-libc \
  musl-libc-static \
  musl-devel

echo "[virtualization] installing virt-manager and libvirt"
rpm-ostree install \
  virt-manager \
  libvirt

echo "[rocm] installing ROCm stack for AMD GPU support"
rpm-ostree install \
  rocm \
  rocm-hip \
  rocm-hip-devel \
  rocm-opencl \
  rocm-smi \
  rocm-clinfo

# cmake skipped - cmake-filesystem version mismatch
echo "[dev-tools] installing additional development tools"
rpm-ostree install \
  golang \
  libcec

echo "[ghostty] installing ghostty terminal from COPR"
dnf5 -y copr enable scottames/ghostty
dnf5 -y install ghostty
dnf5 -y copr disable scottames/ghostty

echo "[antigravity] adding Google Antigravity IDE repository"
cat > /etc/yum.repos.d/antigravity.repo << 'EOF'
[antigravity-rpm]
name=Antigravity RPM Repository
baseurl=https://us-central1-yum.pkg.dev/projects/antigravity-auto-updater-dev/antigravity-rpm
enabled=1
gpgcheck=0
EOF

echo "[antigravity] installing Google Antigravity IDE"
dnf5 -y install antigravity

echo "[antigravity] disabling repository to prevent auto-updates in final image"
sed -i 's/^enabled=1/enabled=0/' /etc/yum.repos.d/antigravity.repo

echo "[docker-ce] installing Docker CE and plugins"
dnf5 -y install --enablerepo=docker-ce-stable \
  docker-ce \
  docker-ce-cli \
  docker-buildx-plugin \
  docker-compose-plugin \
  docker-ce-rootless-extras

echo "[vscode] installing Visual Studio Code"
dnf5 -y install --enablerepo=code code

echo "[tailscale] installing Tailscale VPN"
dnf5 -y install --enablerepo=tailscale-stable tailscale

echo "[incus] installing Incus container/VM manager"
dnf5 -y install \
  incus \
  incus-agent \
  lxc

echo "[cockpit] installing Cockpit web console"
dnf5 -y install \
  cockpit-bridge \
  cockpit-machines \
  cockpit-networkmanager \
  cockpit-ostree \
  cockpit-podman \
  cockpit-selinux \
  cockpit-storaged \
  cockpit-system

echo "[qemu] installing additional QEMU/virtualization packages"
dnf5 -y install \
  edk2-ovmf \
  qemu \
  qemu-char-spice \
  qemu-device-display-virtio-gpu \
  qemu-device-display-virtio-vga \
  qemu-device-usb-redirect \
  qemu-img \
  qemu-system-x86-core \
  qemu-user-binfmt \
  qemu-user-static \
  virt-viewer \
  libvirt-nss

echo "[hardware] installing hardware/peripheral tools"
dnf5 -y install \
  bluez-deprecated \
  joystick \
  picocom \
  socat \
  solaar \
  wmctrl

echo "[dev-extras] installing extra dev tools from upstream"
dnf5 -y install \
  android-tools \
  bcc \
  bpftop \
  bpftrace \
  cascadia-code-fonts \
  flatpak-builder \
  genisoimage \
  git-subtree \
  git-svn \
  iotop \
  nicstat \
  numactl \
  p7zip \
  p7zip-plugins \
  podman-compose \
  podman-machine \
  podman-tui \
  sysprof \
  tiptop \
  trace-cmd \
  udica \
  ydotool

### Enable services

echo "[services] enabling systemd services"
systemctl enable podman.socket
systemctl enable docker.socket
systemctl enable libvirtd
systemctl enable tailscaled

# Homebrew services (from OCI layer)
systemctl enable brew-setup.service || true
systemctl enable brew-upgrade.timer || true
systemctl enable brew-update.timer || true
