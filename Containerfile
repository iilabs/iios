# OCI layer images for modular components
ARG COMMON_IMAGE="ghcr.io/projectbluefin/common:latest"
ARG BREW_IMAGE="ghcr.io/ublue-os/brew:latest"

FROM ${COMMON_IMAGE} AS common
FROM ${BREW_IMAGE} AS brew

# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /
# Copy shared system files from upstream OCI layers
COPY --from=common /system_files/shared /system_files/shared
COPY --from=brew /system_files /system_files/brew

# Base Image
FROM ghcr.io/ublue-os/bluefin-dx:stable

# Copy Squid CA certificate for SSL interception
COPY squid-ca.pem /etc/pki/ca-trust/source/anchors/squid-ca.pem
RUN update-ca-trust

# Accept proxy settings from build arguments
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY
ENV http_proxy=${HTTP_PROXY} \
    https_proxy=${HTTPS_PROXY} \
    no_proxy=${NO_PROXY}

## Other possible base images include:
# FROM ghcr.io/ublue-os/bazzite:latest
# FROM ghcr.io/ublue-os/bluefin-nvidia:stable
# 
# ... and so on, here are more base images
# Universal Blue Images: https://github.com/orgs/ublue-os/packages
# Fedora base image: quay.io/fedora/fedora-bootc:41
# CentOS base images: quay.io/centos-bootc/centos-bootc:stream10
RUN echo 1

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=tmpfs,target=/var/tmp \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh && \
    ostree container commit
    
### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
