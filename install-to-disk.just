mapper_name := "cryptroot"
boot_label := "BOOT"
root_label := "ROOT"
boot_size := "2G"
mount_point := "/mnt"
image := "ghcr.io/projectbluefin/dakota:latest"

default: install

install target_disk="":
    #!/usr/bin/env bash
    set -e

    just -f ./Justfile build-containerfile

    DISK="{{target_disk}}"
    
    if [ -z "$DISK" ]; then
        echo "Select Target Drive:"
        DISK=$(gum input --placeholder "sda" --header "Enter drive label (ex: sda)")
    fi
    if [ -z "$DISK" ]; then
        gum style --foreground 1 "Error: No drive selected."
        exit 1
    fi
    if [[ "$DISK" != /dev/* ]]; then
        DISK="/dev/$DISK"
    fi
    PART_PREFIX=""
    if [[ "$DISK" =~ "nvme" || "$DISK" =~ "mmcblk" || "$DISK" =~ "loop" ]]; then
        PART_PREFIX="p"
    fi
    
    DEV_BOOT="${DISK}${PART_PREFIX}1"
    DEV_ROOT="${DISK}${PART_PREFIX}2"
    MAPPER="/dev/mapper/{{mapper_name}}"

    # Confirmation, this wipe the disk
    echo ""
    gum style --border normal --margin "1" --padding "1" --border-foreground 212 \
        "Target Disk: $DISK" \
        "Boot Partition: $DEV_BOOT" \
        "Root Partition: $DEV_ROOT" \
        "Image: {{image}}"

    if ! gum confirm "⚠️  WARNING: This will WIPE ALL DATA and might cause trouble (untested) on $DISK. Continue?"; then
        gum style --foreground 1 "You chose safety..."
        exit 1
    fi

    # Making sure there are no old mounts/cryptsetup
    gum spin --spinner dot --title "Cleaning up previous mounts..." -- \
        bash -c "sudo umount -R {{mount_point}} 2>/dev/null || true; sudo cryptsetup close {{mapper_name}} 2>/dev/null || true"

    # Create partitions
    echo "-> Wiping and Partitioning..."
    sudo wipefs -a $DISK
    sudo sgdisk -o $DISK
    sudo sgdisk -n 1:0:+{{boot_size}} -t 1:ef00 -c 1:"{{boot_label}}" $DISK
    sudo sgdisk -n 2:0:0 -t 2:8300 -c 2:"{{root_label}}" $DISK

    # Create LUKS volume
    echo "-> Setting up LUKS and Filesystems..."
    sudo cryptsetup luksFormat --type luks2 $DEV_ROOT
    sudo cryptsetup open $DEV_ROOT {{mapper_name}}

    # Create filesystems
    sudo mkfs.fat -F 32 -n {{boot_label}} $DEV_BOOT
    sudo mkfs.btrfs -L {{root_label}} -f $MAPPER

    # Mount them to /mnt
    sudo mount $MAPPER {{mount_point}}
    sudo mount --mkdir $DEV_BOOT {{mount_point}}/boot

    # Get the uuids
    BOOT_UUID=$(sudo blkid -s UUID -o value $DEV_BOOT)
    LUKS_UUID=$(sudo blkid -s UUID -o value $DEV_ROOT)

    echo "-> LUKS UUID: $LUKS_UUID"
    echo "-> BOOT UUID: $BOOT_UUID"

    gum style --foreground 212 "Running bootc install, this will ignore all error to fix the fsfreeze issue, don't processed if there is other errors..."
    sudo podman run \
        --rm --privileged --pid=host \
        -it \
        -v /etc/containers:/etc/containers:Z \
        -v /var/lib/containers:/var/lib/containers:Z \
        -v /dev:/dev \
        -e RUST_LOG=debug \
        -v "/mnt:/mnt" \
        --security-opt label=type:unconfined_t \
        "ghcr.io/projectbluefin/dakota:latest" bootc install to-filesystem /mnt \
        --composefs-backend \
        --bootloader systemd \
        --karg splash \
        --karg quiet \
        --karg rd.luks.name=${LUKS_UUID}=cryptroot \
        --karg root=/dev/mapper/cryptroot \
        --karg rootflags=subvol=/ \
        --karg rw || true

     gum style --foreground 212 "Ignore the fsfreeze boot error"


    # Re-mount as rw
    echo "Configuring Bootloader and Fstab..."
    sudo mount -o remount,rw {{mount_point}}
    sudo mount -o remount,rw {{mount_point}}/boot

    # Get variable for boot
    DEPLOY_DIR=$(sudo find {{mount_point}}/state/deploy -maxdepth 1 -type d -name '*' | grep -v '{{mount_point}}/state/deploy$' | head -n 1)
    BOOT_ENTRY=$(ls -d {{mount_point}}/boot/loader/entries/*)
    COMPOSEFS_HASH=$(basename "$DEPLOY_DIR")
    
    # Set bootloader entry
    sudo sed -i \
      "s|^options.*|options rd.luks.name=${LUKS_UUID}={{mapper_name}} rd.luks.uuid=luks-${LUKS_UUID} root=$MAPPER rootflags=subvol=/ rw boot=UUID=${BOOT_UUID} composefs=${COMPOSEFS_HASH} splash quiet|" \
      "$BOOT_ENTRY"

    # Create crypttab
    sudo bash -c "cat << EOF > ${DEPLOY_DIR}/etc/crypttab
    {{mapper_name}} UUID=${LUKS_UUID} none luks
    EOF"

    # Create fstab
    sudo bash -c "cat << EOF > ${DEPLOY_DIR}/etc/fstab
    $MAPPER  /      btrfs  defaults  0 0
    UUID=${BOOT_UUID}      /boot  vfat   defaults  0 2
    EOF"

    sync
    sudo umount -R {{mount_point}}
    sudo cryptsetup close {{mapper_name}}
    
    gum style --foreground 212 "Installation Complete."
