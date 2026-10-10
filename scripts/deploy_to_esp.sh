#!/usr/bin/env bash
set -e

EFI_SRC="/Users/sritulasiram/Documents/Projects/efi/EFI"
EFI_DISK="${1:-disk0s1}"
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

# Verify deployed PlatformInfo on the ESP
echo "[*] Verifying deployed PlatformInfo (SMBIOS) on ESP..."
python3 -c "
import plistlib
try:
    with open('$MOUNT_POINT/EFI/OC/config.plist', 'rb') as f:
        cfg = plistlib.load(f)
    gen = cfg.get('PlatformInfo', {}).get('Generic', {})
    serial = gen.get('SystemSerialNumber', 'MISSING')
    mlb = gen.get('MLB', 'MISSING')
    uuid = gen.get('SystemUUID', 'MISSING')
    model = gen.get('SystemProductName', 'MISSING')
    print(f'    ✓ Model:  {model}')
    print(f'    ✓ Serial: {serial}')
    print(f'    ✓ MLB:    {mlb}')
    print(f'    ✓ UUID:   {uuid}')
    if serial == 'CHANGEME':
        print('    [!] WARNING: SystemSerialNumber is set to CHANGEME!')
    else:
        print('    [✓] Valid hardware SMBIOS confirmed active on ESP!')
except Exception as e:
    print(f'    [!] Warning checking SMBIOS: {e}')
"

# 4. Flush and unmount
sync
echo "[*] Unmounting /dev/${EFI_DISK}..."
diskutil unmount "/dev/${EFI_DISK}"

echo "=================================================================="
echo "[SUCCESS] EFI deployed to your boot partition!"
echo "Next step: Restart your Mac, press Spacebar at OpenCore boot picker,"
echo "           and select 'Reset NVRAM' once to apply boot-args and variables."
echo "=================================================================="
