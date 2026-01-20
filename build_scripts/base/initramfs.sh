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

# instal the Bluefin plymouth watermark
cp /usr/share/plymouth/themes/spinner/watermark.png "${INITRAMFS_EXTRACT_DIR}/usr/share/plymouth/themes/spinner/watermark.png"

# compressing, then putting the newly generated initramfs back in
find . | ${CPIO} -o -H newc > $NEW_INITRAMFS_BLOCK_FILE
zstd $NEW_INITRAMFS_BLOCK_FILE
dd if=${NEW_INITRAMFS_BLOCK_FILE}.zst of=${INITRAMFS} seek="${INITIAL_BLOCK}"
