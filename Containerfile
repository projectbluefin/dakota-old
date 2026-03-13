FROM scratch AS ctx

COPY files /files
COPY build_scripts /build_scripts
COPY --from=ghcr.io/projectbluefin/common:latest@sha256:69e0d5c9ec9fe3766dc82453d96b098874ca3469a8d7b1a272677eb75e9c24e4 /system_files/bluefin /files
COPY --from=ghcr.io/projectbluefin/common:latest@sha256:69e0d5c9ec9fe3766dc82453d96b098874ca3469a8d7b1a272677eb75e9c24e4 /system_files/shared /files
COPY --from=ghcr.io/ublue-os/brew:latest@sha256:2eca44f5b4b58b8271a625d61c2c063b7c8776f68d004ae67563e2a79450be9c /system_files /files
COPY --from=busybox:musl@sha256:19b646668802469d968a05342a601e78da4322a414a7c09b1c9ee25165042138 /bin/busybox /files/usr/bin/busybox
COPY build.sh /build.sh
COPY devel-build.sh /devel-build.sh

FROM quay.io/gnome_infrastructure/gnome-build-meta:gnomeos-devel-nightly@sha256:95ab7b4deb621c28f86b641a75e7f253e77c4a99e69aa7ac6155c9bee6d1a57d AS devel

RUN --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/boot \
    --mount=type=tmpfs,dst=/run \
    --mount=type=bind,from=ctx,source=/,dst=/tmp/ctx \
    /tmp/ctx/devel-build.sh

FROM quay.io/gnome_infrastructure/gnome-build-meta:gnomeos-nightly@sha256:7309db653f131b4fa4db3275ef2ab63efecd14a3e1e3dbe5d219a49211d33677

ARG IMAGE_NAME="${IMAGE_NAME:-dakota}"
ARG IMAGE_VENDOR="${IMAGE_VENDOR:-projectbluefin}"

RUN --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/boot \
    --mount=type=tmpfs,dst=/run \
    --mount=type=bind,from=ctx,source=/,dst=/tmp/ctx \
    --mount=type=bind,from=devel,source=/,dst=/tmp/ctx-devel \
    /tmp/ctx/build.sh

LABEL containers.bootc=1
LABEL org.opencontainers.image.source="https://github.com/projectbluefin/dakota"

RUN bootc container lint
