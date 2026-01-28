mapper_name := "cryptroot"
boot_label := "BOOT"
root_label := "ROOT"
boot_size := "2G"
mount_point := "/var/mnt"
image := "ghcr.io/projectbluefin/dakota"

_default: install

check-deps:
    #!/usr/bin/env bash
    set -e
    deps=(tmux gum fzf wipefs sgdisk mkfs.fat mkfs.btrfs mkfs.ext4 podman cryptsetup udevadm)
    missing=()
    for dep in "${deps[@]}"; do
        command -v "$dep" >/dev/null 2>&1 || missing+=("$dep")
    done
    if (( ${#missing[@]} )); then
        printf 'Missing dependencies:\n'
        printf '  - %s\n' "${missing[@]}"
        exit 1
    fi

install:
    #!/usr/bin/env bash
    set -e
    just -f ./install-to-disk.just check-deps

    # Tmux init
    if [ -z "$TMUX" ]; then
        gum style --foreground "#006ff6ff" "You need a podman build of Dakota. Is it already done, or do you want to build it now?"
        gum style --faint --italic --foreground "#ff0000" "If you don't have a build ready, bootc will try to pull for ghcr.io and the install will fail"
        ACCEPT=$(gum choose "Build it now" "Already done, skip")

        if [ "$ACCEPT" = "Build it now" ]; then
            sudo -v
            gum style --foreground "#0fca63" "☕️ Get a cup of coffee! The installer will start after the image is built.."
            sleep 2s
            just check-deps
            just init-submodules
            just build-containerfile
        fi

        exec tmux new-session -s dakota-install -c "$PWD" "just -f ./install-to-disk.just install; echo 'Press Enter to close'; read"
    fi

    # Create splits
    if [ "$(tmux list-panes | wc -l)" -eq 1 ]; then
        tmux split-window -v -p 40
        tmux select-pane -t 0
    fi

    LOG_FILE=$(mktemp /tmp/dakota-install.XXXXXX.log)
    
    # Logs pane setup
    tmux send-keys -t 1 C-c "tail -f $LOG_FILE" C-m

    # Initialize Log
    echo -e "\n--- 🪵 Dakota Installation Logs [$(date)] ---\n" > "$LOG_FILE"
    export LOG_FILE

    # Actual install logic
    gum style --bold '🦕 DAKOTA CLI INSTALLER'
    gum style --faint --italic --foreground 212 "Thank you for testing Dakota!"
    gum style --foreground 212 "The installer needs sudo permissions to manage disks..."
    sudo -v

    # Disk Selection
    if [ -z "$DISK" ]; then
        DISK=$(lsblk -d -n -o NAME,TRAN | awk '$2 != "" {print $1}' |
        fzf --header='Select installation disk (🚧 WILL BE WIPED! 🚧)' --preview 'lsblk /dev/{}')
    fi
    if [ -z "$DISK" ]; then
        gum style --foreground 1 "Error: No drive selected."
        exit 1
    fi
    if [[ "$DISK" != /dev/* ]]; then DISK="/dev/$DISK"; fi
    
    # Filesystem Selection
    gum style --foreground 212 "Choose your preferred root filesystem:"
    # FS_TYPE=$(gum choose --header "~ Btrfs is recommanded" "btrfs" "ext4" "xfs")
    FS_TYPE=$(gum choose --header "~ Btrfs is recommanded" "btrfs" "ext4") # XFS disabled until it supports verity-fs

    PART_PREFIX=""
    if [[ "$DISK" =~ "nvme" || "$DISK" =~ "mmcblk" || "$DISK" =~ "loop" ]]; then PART_PREFIX="p"; fi
    
    DEV_BOOT="${DISK}${PART_PREFIX}1"
    DEV_ROOT="${DISK}${PART_PREFIX}2"
    MAPPER="/dev/mapper/{{mapper_name}}"

    # Installer info
    gum style --align left --border normal --margin "1" --padding "1" --border-foreground 212 \
        "$(gum style --bold '🦖 DAKOTA CLI INSTALLER')" \
        "$(gum style --faint 'Configuration:')" \
        "" \
        "💽 Target Disk:     ${DISK:-'None'}" \
        "📂 Filesystem:      ${FS_TYPE}" \
        "🔒️ Root Partition:  ${DEV_ROOT:-'None'}" \
        "🥾 Boot Partition:  ${DEV_BOOT:-'None'}" \
        "🖼️ Image:           {{image}}" \
        "🪵 Log File:        ${LOG_FILE:-'None'}"

    if ! gum confirm "⚠️  WARNING: This will WIPE ALL DATA on $DISK. Continue?"; then
        gum style --foreground 1 "Aborted."
        exit 1
    fi

    gum spin --spinner dot --title "Cleaning up previous mounts..." -- bash -c \
        "{ sudo umount -R {{mount_point}} 2>/dev/null || true; sudo cryptsetup close {{mapper_name}} 2>/dev/null || true; } >> \"$LOG_FILE\" 2>&1"

    gum spin --spinner dot --title "Wiping and Partitioning $DISK..." -- bash -c "
    {
        sudo umount /dev/sda* || true
        sleep 2
        sudo wipefs -a $DISK && \
        sudo sgdisk -o $DISK && \
        sudo sgdisk -n 1:0:+{{boot_size}} -t 1:ef00 -c 1:\"{{boot_label}}\" $DISK && \
        sudo sgdisk -n 2:0:0 -t 2:8300 -c 2:\"{{root_label}}\" $DISK
    } >> \"$LOG_FILE\" 2>&1"

    # LUKS password setup
    while true; do
        PASS=$(gum input --password --placeholder "Enter desired LUKS Passphrase")
        PASS_CONFIRM=$(gum input --password --placeholder "Confirm LUKS Passphrase")
        if [ "$PASS" = "$PASS_CONFIRM" ] && [ -n "$PASS" ]; then break; else gum style --foreground 1 "Passwords do not match."; fi
    done

    sudo udevadm settle

    gum spin --spinner dot --title "Formatting LUKS Volume..." -- bash -c \
        "{ echo -n \"$PASS\" | sudo cryptsetup luksFormat --type luks2 \"$DEV_ROOT\" -; } >> \"$LOG_FILE\" 2>&1"

    gum spin --spinner meter --title "Opening LUKS Volume..." -- bash -c \
        "{ echo -n \"$PASS\" | sudo cryptsetup open \"$DEV_ROOT\" {{mapper_name}} -; } >> \"$LOG_FILE\" 2>&1"

    export PASS=""
    unset PASS PASS_CONFIRM

    # Filesystem Creation
    gum spin --spinner hamburger --title "Creating filesystems ($FS_TYPE) on $DISK..." -- bash -c "
        {
            sudo udevadm settle
            sudo mkfs.fat -F 32 -n {{boot_label}} $DEV_BOOT
            if [ \"$FS_TYPE\" = \"btrfs\" ]; then
                sudo mkfs.btrfs -L {{root_label}} -f $MAPPER
            elif [ \"$FS_TYPE\" = \"xfs\" ]; then
                sudo mkfs.xfs -L {{root_label}} $MAPPER
            else
                sudo mkfs.ext4 -O verity -L {{root_label}} -F $MAPPER
            fi
            sudo mount $MAPPER {{mount_point}}
            sudo mount --mkdir $DEV_BOOT {{mount_point}}/boot
        } >> \"$LOG_FILE\" 2>&1"

    BOOT_UUID=$(sudo blkid -s UUID -o value $DEV_BOOT)
    LUKS_UUID=$(sudo blkid -s UUID -o value $DEV_ROOT)

    echo "-> FS Type: $FS_TYPE" >> "$LOG_FILE"
    echo "-> LUKS UUID: $LUKS_UUID" >> "$LOG_FILE"
    echo "-> BOOT UUID: $BOOT_UUID" >> "$LOG_FILE"

    gum spin --spinner points \
    --title 'Installing to filesystem...' \
    -- bash -c "
        {
            sudo -n podman run --tty --rm --privileged --pid=host \
                -v /etc/containers:/etc/containers:Z \
                -v /var/lib/containers:/var/lib/containers:Z \
                -v /dev:/dev \
                -e RUST_LOG=debug \
                -v '{{mount_point}}:{{mount_point}}' \
                --security-opt label=type:unconfined_t \
                '{{image}}:latest' bootc install to-filesystem {{mount_point}} \
                --composefs-backend --bootloader systemd \
                --karg splash --karg quiet \
                --karg rd.luks.name=${LUKS_UUID}=cryptroot \
                --karg root=/dev/mapper/cryptroot \
                --karg rw
        } >> \"$LOG_FILE\" 2>&1 || true
    "

    echo "Installation over, ignore fsfreeze error" >> "$LOG_FILE"

    sudo mount -o remount,rw {{mount_point}} >> "$LOG_FILE"
    sudo mount -o remount,rw {{mount_point}}/boot >> "$LOG_FILE"
    
    DEPLOY_DIR=$(sudo find {{mount_point}}/state/deploy -maxdepth 1 -type d ! -path {{mount_point}}/state/deploy | head -n 1)
    BOOT_ENTRY=$(ls -d {{mount_point}}/boot/loader/entries/*.conf | head -n 1)
    COMPOSEFS_HASH=$(basename "$DEPLOY_DIR")
    

    ROOT_FLAGS=""
    if [ "$FS_TYPE" = "btrfs" ]; then
        ROOT_FLAGS="rootflags=subvol=/"
    fi

    echo "Modifying boot entry: $BOOT_ENTRY" >> "$LOG_FILE"
    sudo sed -i \
      "s|^options.*|options rd.luks.name=${LUKS_UUID}={{mapper_name}} rd.luks.uuid=luks-${LUKS_UUID} root=$MAPPER $ROOT_FLAGS rw boot=UUID=${BOOT_UUID} composefs=${COMPOSEFS_HASH} splash quiet|" \
      "$BOOT_ENTRY" >> "$LOG_FILE"

    echo "Creating crypttab..." >> "$LOG_FILE"
    sudo bash -c "cat << EOF > ${DEPLOY_DIR}/etc/crypttab
    {{mapper_name}} UUID=${LUKS_UUID} none luks
    EOF" >> "$LOG_FILE"

    echo "Creating fstab..." >> "$LOG_FILE"
    sudo bash -c "cat << EOF > ${DEPLOY_DIR}/etc/fstab
    $MAPPER  /      $FS_TYPE  defaults  0 0
    UUID=${BOOT_UUID}      /boot  vfat   defaults  0 2
    EOF" >> "$LOG_FILE"

    echo "Cleaning up mounts..."
    sync
    sudo umount -R {{mount_point}} >> "$LOG_FILE"
    sudo cryptsetup close {{mapper_name}} >> "$LOG_FILE"

    gum style --foreground 2 "✅ Installation complete! You can now boot from the Dakota disk!."

    bash -c 'read -rsn1 -p "Press any key to close the installer..." && tmux kill-session -t dakota-install'