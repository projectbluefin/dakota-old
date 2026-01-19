#!/bin/bash
set -exuo pipefail

CPIO="busybox cpio"
INITRAMFS="$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E "*.img" | tail -n 1)/initramfs.img"
INITRAMFS_EXTRACT_BLOCK_FILE="$(mktemp)"
INITRAMFS_EXTRACT_DIR="$(mktemp -d)"
NEW_INITRAMFS_BLOCK_FILE="$(mktemp)"

# GnomeOS's initramfs is multi-stage, so we need to get the part that has what we need
INITIAL_BLOCK="$(cd "$(mktemp -d)" && ${CPIO} -idvm < "${INITRAMFS}" 2>&1 | tail -n 1 | cut -f1 -d' ')"
dd if="${INITRAMFS}" skip="${INITIAL_BLOCK}" of="${INITRAMFS_EXTRACT_BLOCK_FILE}"

# extraction
mkdir -p "${INITRAMFS_EXTRACT_DIR}"
cd "${INITRAMFS_EXTRACT_DIR}"
zstdcat "${INITRAMFS_EXTRACT_BLOCK_FILE}" | ${CPIO} -idmv

# instal ostree boot support
mkdir -p "${INITRAMFS_EXTRACT_DIR}/usr/lib/ostree"
cp /usr/lib/ostree/ostree-prepare-root "${INITRAMFS_EXTRACT_DIR}/usr/lib/ostree/"
ldd /usr/lib/ostree/ostree-prepare-root | grep -o '/[^ ]*' | xargs -I '{}' cp --parents -n -v '{}' "${INITRAMFS_EXTRACT_DIR}/"
cp /usr/lib/systemd/system/ostree-prepare-root.service "${INITRAMFS_EXTRACT_DIR}/usr/lib/systemd/system/"
cp /usr/lib/systemd/system/ostree-prepare-root.service "${INITRAMFS_EXTRACT_DIR}/usr/lib/systemd/system/"
ln -s /usr/lib/systemd/system/ostree-prepare-root.service "${INITRAMFS_EXTRACT_DIR}/usr/lib/systemd/system/initrd-root-fs.target.wants/"

# compressing, then putting the newly generated initramfs back in
find . | ${CPIO} -o -H newc > $NEW_INITRAMFS_BLOCK_FILE
zstd $NEW_INITRAMFS_BLOCK_FILE
dd if=${NEW_INITRAMFS_BLOCK_FILE}.zst of=${INITRAMFS} seek="${INITIAL_BLOCK}"
