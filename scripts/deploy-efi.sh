#!/usr/bin/env bash
# ==============================================================================
# ASUS ROG Strix GL503GE - Deploy EFI to the boot ESP
# ==============================================================================
# Copies ./EFI to an EFI System Partition, using your own SMBIOS config.
#
#   sudo deploy-efi.sh [diskXsY] [--dry-run] [--yes] [--keep N]
#
#   diskXsY    the ESP to write. Optional only when exactly one internal ESP exists.
#   --dry-run  run every check and show the plan, but do not mount or write anything
#   --yes      skip the confirmation prompt
#   --keep N   keep the newest N Desktop backups (default 5)
#
# Needs EFI/OC/config.personal.plist (gitignored copy of config.plist with real
# SMBIOS). A backup is taken first and restored automatically if the copy fails.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

EFI_SRC="${EFI_SRC:-$SCRIPT_DIR/../EFI}"
PERSONAL_CFG="$EFI_SRC/OC/config.personal.plist"
EFI_DISK=""
KEEP_BACKUPS=5

usage() { sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//' | grep -v '^=*$'; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --yes|-y)  ASSUME_YES=1 ;;
        --keep)    shift; KEEP_BACKUPS="${1:?--keep needs a number}" ;;
        -h|--help) usage; exit 0 ;;
        disk[0-9]*s[0-9]*) EFI_DISK="$1" ;;
        *) usage; die "Unknown argument: $1" ;;
    esac
    shift
done
[[ "$KEEP_BACKUPS" =~ ^[0-9]+$ ]] || die "--keep needs a number"

if [[ "${DRY_RUN:-0}" != "1" ]]; then
    ensure_root "$0" "$@"
fi

echo "=================================================================="
echo " Deploy EFI to ESP${DRY_RUN:+  (dry run)}"
echo "=================================================================="

# ---- 1. Source and SMBIOS checks (before anything touches a disk) -----------
[[ -d "$EFI_SRC" ]] || die "Source EFI directory not found: $EFI_SRC"
[[ -f "$PERSONAL_CFG" ]] || die "$PERSONAL_CFG not found. Copy config.plist to config.personal.plist and fill in PlatformInfo > Generic first."

python3 -I -c "
import plistlib, sys
with open(sys.argv[1], 'rb') as f:
    gen = plistlib.load(f).get('PlatformInfo', {}).get('Generic', {})
placeholders = ('CHANGEME', '00000000-0000-0000-0000-000000000000')
bad = [k for k in ('SystemSerialNumber', 'MLB', 'SystemUUID') if str(gen.get(k, 'CHANGEME')) in placeholders]
sys.exit(1 if bad else 0)
" "$PERSONAL_CFG" || die "config.personal.plist still has CHANGEME / missing SMBIOS values (SystemSerialNumber, MLB, SystemUUID)."
ok "SMBIOS values present in config.personal.plist"

OCVALIDATE="$(command -v ocvalidate || true)"
[[ -z "$OCVALIDATE" && -x "$SCRIPT_DIR/../utilities/ocvalidate" ]] && OCVALIDATE="$SCRIPT_DIR/../utilities/ocvalidate"
if [[ -n "$OCVALIDATE" ]]; then
    "$OCVALIDATE" "$PERSONAL_CFG" >/dev/null || die "ocvalidate reports problems in config.personal.plist (run: $OCVALIDATE $PERSONAL_CFG)"
    ok "ocvalidate passed"
else
    warn "ocvalidate not found; skipping config validation (put it in PATH or utilities/)."
fi

# ---- 2. Pick and verify the ESP ---------------------------------------------
describe_disk() { # diskXsY -> "Samsung SSD 980, 500.1 GB"
    local whole name size
    whole="$(diskutil info -plist "$1" | plutil -extract ParentWholeDisk raw - 2>/dev/null)"
    name="$(diskutil info "$whole" | awk -F': +' '/Device \/ Media Name/ {print $2}')"
    size="$(diskutil info "$whole" | awk -F': +' '/Disk Size/ {print $2}' | cut -d' ' -f1-2)"
    echo "${name:-unknown}, ${size:-?}"
}

if [[ -z "$EFI_DISK" ]]; then
    CANDIDATES=()
    while read -r c; do CANDIDATES+=("$c"); done < <(diskutil list internal | awk '$2=="EFI" && $NF ~ /^disk[0-9]+s[0-9]+$/ {print $NF}')
    if [[ ${#CANDIDATES[@]} -eq 1 ]]; then
        EFI_DISK="${CANDIDATES[0]}"
    else
        echo "Internal EFI partitions found:"
        for c in "${CANDIDATES[@]}"; do echo "  $c   ($(describe_disk "$c"))"; done
        die "Pick one explicitly: sudo $0 diskXsY"
    fi
fi

[[ "$(diskutil info -plist "/dev/${EFI_DISK}" | plutil -extract Content raw - 2>/dev/null)" == "EFI" ]] \
    || die "/dev/${EFI_DISK} is not an EFI System Partition."
ok "Target ESP: /dev/${EFI_DISK} ($(describe_disk "$EFI_DISK"))"

BACKUP_ROOT="$(real_home)/Desktop"
BACKUP_DIR="${BACKUP_ROOT}/EFI_Backup_$(date +%Y%m%d_%H%M%S)"

if [[ "${DRY_RUN:-0}" == "1" ]]; then
    echo ""
    echo "Plan:"
    echo "  1. mount /dev/${EFI_DISK}"
    echo "  2. back up the current EFI to ${BACKUP_DIR} (keep newest ${KEEP_BACKUPS})"
    echo "  3. rsync ${EFI_SRC}/ -> ESP/EFI (delete extras, config.personal.plist excluded)"
    echo "  4. install config.personal.plist as OC/config.plist, verify, unmount"
    echo "  5. restore the backup automatically if anything fails"
    exit 0
fi

confirm "Overwrite the EFI on /dev/${EFI_DISK} with ${EFI_SRC}?" || { echo "Aborted."; exit 0; }

# ---- 3. Mount ----------------------------------------------------------------
WAS_MOUNTED=1
MOUNT_POINT="$(diskutil info -plist "/dev/${EFI_DISK}" | plutil -extract MountPoint raw - 2>/dev/null || true)"
if [[ -z "$MOUNT_POINT" || ! -d "$MOUNT_POINT" ]]; then
    WAS_MOUNTED=0
    info "Mounting /dev/${EFI_DISK}..."
    diskutil mount "/dev/${EFI_DISK}" >/dev/null
    MOUNT_POINT="$(diskutil info -plist "/dev/${EFI_DISK}" | plutil -extract MountPoint raw - 2>/dev/null || true)"
fi
[[ -n "$MOUNT_POINT" && -d "$MOUNT_POINT" ]] || die "Could not determine the mount point for /dev/${EFI_DISK}"
ok "Mounted at $MOUNT_POINT"

cleanup() {
    sync
    if [[ "$WAS_MOUNTED" == "0" ]]; then diskutil unmount "/dev/${EFI_DISK}" >/dev/null 2>&1 || true; fi
}
trap cleanup EXIT

# ---- 4. Backup ----------------------------------------------------------------
HAVE_BACKUP=0
if [[ -d "$MOUNT_POINT/EFI" ]]; then
    info "Backing up current EFI to $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"
    cp -R "$MOUNT_POINT/EFI" "$BACKUP_DIR/"
    [[ -n "${SUDO_USER:-}" ]] && chown -R "$SUDO_USER" "$BACKUP_DIR"
    HAVE_BACKUP=1
    ok "Backup created"
    # Keep only the newest N backups
    # shellcheck disable=SC2012
    ls -1dt "$BACKUP_ROOT"/EFI_Backup_* 2>/dev/null | tail -n +"$((KEEP_BACKUPS + 1))" | while read -r old; do
        rm -rf "$old" && echo "    pruned old backup: $old"
    done
fi

restore_and_die() {
    warn "$1"
    if [[ "$HAVE_BACKUP" == "1" ]]; then
        warn "Restoring the backup to the ESP..."
        rsync -rt --delete "$BACKUP_DIR/EFI/" "$MOUNT_POINT/EFI/" && ok "Previous EFI restored." \
            || warn "Restore failed; your backup is at $BACKUP_DIR"
    fi
    exit 1
}

# ---- 5. Copy -------------------------------------------------------------------
info "Copying EFI to $MOUNT_POINT/EFI..."
mkdir -p "$MOUNT_POINT/EFI"
# -rt only: FAT cannot hold POSIX perms/owners. The personal config is installed separately below.
rsync -rtv --delete --exclude "config.personal.plist" "$EFI_SRC/" "$MOUNT_POINT/EFI/" \
    || restore_and_die "rsync failed."
cp -f "$PERSONAL_CFG" "$MOUNT_POINT/EFI/OC/config.plist" || restore_and_die "Could not install config.personal.plist."

# ---- 6. Verify ------------------------------------------------------------------
for f in BOOT/BOOTx64.efi OC/OpenCore.efi OC/config.plist; do
    [[ -s "$MOUNT_POINT/EFI/$f" ]] || restore_and_die "Missing or empty after copy: EFI/$f"
done
cmp -s "$PERSONAL_CFG" "$MOUNT_POINT/EFI/OC/config.plist" || restore_and_die "config.plist on the ESP does not match config.personal.plist."

python3 -I -c "
import plistlib, sys
with open(sys.argv[1], 'rb') as f:
    gen = plistlib.load(f).get('PlatformInfo', {}).get('Generic', {})
for label, key in (('Model', 'SystemProductName'), ('Serial', 'SystemSerialNumber'), ('MLB', 'MLB'), ('UUID', 'SystemUUID')):
    print(f'    {label:<7}{gen.get(key, \"MISSING\")}')
" "$MOUNT_POINT/EFI/OC/config.plist"

echo "=================================================================="
ok "EFI deployed to /dev/${EFI_DISK}."
echo "Next: restart, press Space at the OpenCore picker and run 'Reset NVRAM' once."
echo "=================================================================="
