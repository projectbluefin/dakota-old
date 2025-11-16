FROM scratch AS ctx

COPY files /files
COPY build.sh /build.sh

FROM ghcr.io/alatiera/gnomeos-custom/gnomeos-homed:nightly

RUN --mount=type=tmpfs,dst=/var \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=tmpfs,dst=/boot \
    --mount=type=tmpfs,dst=/run \
    --mount=type=bind,from=ctx,source=/,dst=/tmp/ctx \
    /tmp/ctx/build.sh

RUN bootc container lint
