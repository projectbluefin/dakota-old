image_name := env("BUILD_IMAGE_NAME", "ghcr.io/projectbluefin/bluefin-dakota")
image_tag := env("BUILD_IMAGE_TAG", "latest")
base_dir := env("BUILD_BASE_DIR", ".")
filesystem := env("BUILD_FILESYSTEM", "btrfs")

build-containerfile $image_name=image_name:
    sudo podman build --format oci --security-opt label=disable --squash-all -t "${image_name}:latest" .

bootc *ARGS:
    sudo podman run \
        --rm --privileged --pid=host \
        -it \
        -v /var/lib/containers:/var/lib/containers \
        -v /dev:/dev \
        -v "{{base_dir}}:/data" \
        --security-opt label=type:unconfined_t \
        -e RUST_LOG=debug \
        "{{image_name}}:{{image_tag}}" bootc {{ARGS}}

generate-bootable-image $base_dir=base_dir $filesystem=filesystem:
    #!/usr/bin/env bash

    just bootc install to-disk --composefs-backend \
        /dev/sdb \
        --filesystem "${filesystem}" \
        --wipe \
        --bootloader systemd \
        --karg systemd.firstboot=no \
        --karg splash \
        --karg quiet \
        --karg console=tty0 \
        --karg systemd.debug_shell=ttyS1

rootful $image=image_name:
    #!/usr/bin/env bash
    podman image scp $USER@localhost::$image root@localhost::$image

run-vm $base_dir=base_dir:
    qemu-system-x86_64 \
        -machine pc-q35-10.1 \
        -m 8G \
        -smp 4 \
        -cpu host \
        -enable-kvm \
        -device virtio-vga \
        -drive if=pflash,format=qcow2,readonly=on,file=/usr/share/edk2/ovmf/OVMF_CODE_4M.qcow2 \
        -drive file={{base_dir}}/bootable.img,format=raw,if=virtio

init-submodules:
    git submodule update --init --recursive

show-me-the-future: check-deps init-submodules build-containerfile generate-bootable-image run-vm

clean:
    rm -f bootable.img

check-deps:
    @command -v podman >/dev/null 2>&1 || (echo "podman is not installed" && exit 1)
    @command -v qemu-system-x86_64 >/dev/null 2>&1 || (echo "qemu-system-x86_64 is not installed" && exit 1)
    @command -v just >/dev/null 2>&1 || (echo "just is not installed" && exit 1)
    @echo "All dependencies are installed."
