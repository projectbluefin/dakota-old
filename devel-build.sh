#!/usr/bin/env bash

set -xeuo pipefail

mkdir /rootfs

copy_binary () {
  local file="$1"
  local rootfs="$2"

  cp --parents -a -n -v "$file" "$rootfs" && \
  ldd "$file" | grep -o '/[^ ]*' | xargs -I '{}' cp -P --parents -n -v '{}' "$rootfs"
}

copy_recursively () {
  local file="$1"
  local rootfs="$2"

  cp --parents -a -n -v -r "$file" "$rootfs"
}

copy_binary /usr/bin/wl-copy /rootfs
copy_binary /usr/bin/wl-paste /rootfs

# gcc
copy_binary /usr/bin/gcc /rootfs
copy_binary /usr/bin/c++ /rootfs
copy_binary /usr/bin/cc /rootfs
copy_binary /usr/bin/cpp /rootfs
copy_binary /usr/bin/gcc-ar /rootfs
copy_binary /usr/bin/gcc-nm /rootfs
copy_binary /usr/bin/gcc-ranlib /rootfs
copy_binary /usr/bin/gcov /rootfs
copy_binary /usr/bin/gcov-tool /rootfs
for f in $(find /usr/bin/x86_64-unknown-linux-gnu-*); do
  copy_binary "$f" /rootfs
done

copy_binary /usr/bin/just /rootfs

# there's no manpages in non-devel ocis, let's add that
copy_recursively /usr/share/man /rootfs

# manually copy completions for wl-copy and wl-paste
copy_recursively /usr/share/bash-completion/completions/wl-copy /rootfs
copy_recursively /usr/share/fish/vendor_completions.d/wl-copy.fish /rootfs
copy_recursively /usr/share/zsh/site-functions/_wl-copy /rootfs

copy_recursively /usr/share/bash-completion/completions/wl-paste /rootfs
copy_recursively /usr/share/fish/vendor_completions.d/wl-paste.fish /rootfs
copy_recursively /usr/share/zsh/site-functions/_wl-paste /rootfs

# stuff for gcc
copy_recursively /usr/share/gcc-* /rootfs
copy_recursively /usr/include/c++ /rootfs
copy_recursively /usr/lib/gcc /rootfs
copy_recursively /usr/libexec/gcc /rootfs
copy_recursively /usr/share/gdb/auto-load/usr/lib/x86_64-linux-gnu/libstdc++.so.*.py /rootfs

mv /rootfs/lib64 /rootfs/usr/lib64
ln -s usr/lib64 /rootfs/lib64

find /rootfs
ls -la /rootfs
