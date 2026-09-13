#!/usr/bin/env bash
set -e

EFI_SRC="/Users/sritulasiram/Documents/Projects/efi/EFI"
EFI_DISK="disk0s1"
BACKUP_DIR="$HOME/Desktop/EFI_Backup_$(date +%Y%m%d_%H%M%S)"

echo "=================================================================="
echo " Deploying updated EFI to ESP (/dev/${EFI_DISK})"
echo "=================================================================="

# Check sudo access
if [ "$EUID" -ne 0 ]; then
    echo "[!] Please run with sudo: sudo ./scripts/deploy_to_esp.sh"
    exit 1
fi

# Ensure target source exists
if [ ! -d "$EFI_SRC" ]; then
    echo "[!] Error: Source EFI directory not found at $EFI_SRC"
    exit 1
fi

# 1. Mount ESP
echo "[*] Mounting /dev/${EFI_DISK}..."
diskutil mount "/dev/${EFI_DISK}"

# Find mount point
MOUNT_POINT=$(diskutil info "/dev/${EFI_DISK}" | awk '/Mount Point:/ {print $NF}')
if [ -z "$MOUNT_POINT" ] || [ ! -d "$MOUNT_POINT" ]; then
    MOUNT_POINT="/Volumes/EFI"
fi

if [ ! -d "$MOUNT_POINT" ]; then
    echo "[!] Error: Could not determine mount point for /dev/${EFI_DISK}"
    exit 1
fi

echo "[+] Mounted at: $MOUNT_POINT"

# 2. Backup existing EFI if present to Desktop
if [ -d "$MOUNT_POINT/EFI" ]; then
    echo "[*] Backing up current EFI to $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"
    cp -R "$MOUNT_POINT/EFI" "$BACKUP_DIR/"
    echo "[+] Backup created successfully at: $BACKUP_DIR"
fi

# 3. Copy new EFI
echo "[*] Copying updated EFI to $MOUNT_POINT/EFI..."
mkdir -p "$MOUNT_POINT/EFI"
rsync -av --delete "$EFI_SRC/" "$MOUNT_POINT/EFI/"

# If personal config exists, deploy it as config.plist on the ESP
if [ -f "$EFI_SRC/OC/config.personal.plist" ]; then
    echo "[+] Applying personal SMBIOS config (config.personal.plist -> config.plist) to ESP..."
    cp -f "$EFI_SRC/OC/config.personal.plist" "$MOUNT_POINT/EFI/OC/config.plist"
fi

# 4. Flush and unmount
sync
echo "[*] Unmounting /dev/${EFI_DISK}..."
diskutil unmount "/dev/${EFI_DISK}"

echo "=================================================================="
echo "[SUCCESS] EFI deployed to your boot partition!"
echo "Next step: Restart your Mac, press Spacebar at OpenCore boot picker,"
echo "           and select 'Reset NVRAM' once to apply boot-args and variables."
echo "=================================================================="
