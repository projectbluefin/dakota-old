#!/usr/bin/env bash

set -xeuo pipefail

mkdir /rootfs

copy_binary () {
  local file="$1"
  local rootfs="$2"

  cp --parents -n -v "$1" "$2" && \
  ldd "$1" | grep -o '/[^ ]*' | xargs -I '{}' cp -P --parents -n -v '{}' "$2"
}

copy_binary /usr/bin/wl-copy /rootfs
copy_binary /usr/bin/wl-paste /rootfs
copy_binary /usr/bin/gcc /rootfs
copy_binary /usr/bin/just /rootfs
# copy_binary /usr/bin/sysprof /rootfs

mv /rootfs/lib64 /rootfs/usr/lib64
ln -s usr/lib64 /rootfs/lib64

find /rootfs
ls -la /rootfs
