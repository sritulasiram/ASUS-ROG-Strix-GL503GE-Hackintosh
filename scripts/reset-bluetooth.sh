#!/usr/bin/env bash
# ==============================================================================
# ASUS ROG Strix GL503GE - Bluetooth Reset & Diagnostics (Intel controller on HS14)
# ==============================================================================
# Restarts bluetoothd and clears its preference files. THIS UNPAIRS ALL DEVICES.
# The preference files are copied to ~/Bluetooth_Backup_<time> first.
#
#   sudo reset-bluetooth.sh [--yes] [--dry-run]
#   sudo reset-bluetooth.sh --check      only report the controller state (no changes)
#
# Exit codes: 0 controller has a valid address, 2 reset done but address still NULL.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

CHECK_ONLY=0

usage() { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//' | grep -v '^=*$'; }

for arg in "$@"; do
    case "$arg" in
        --yes|-y)  ASSUME_YES=1 ;;
        --dry-run) DRY_RUN=1 ;;
        --check)   CHECK_ONLY=1 ;;
        -h|--help) usage; exit 0 ;;
        *) usage; die "Unknown option: $arg" ;;
    esac
done

controller_address() {
    system_profiler SPBluetoothDataType 2>/dev/null | awk -F': ' '/^ +Address:/ {print $2; exit}'
}

report_controller() {
    local addr
    addr="$(controller_address)"
    system_profiler SPBluetoothDataType 2>/dev/null | grep -E "^ +(Address|State|Chipset|Transport|Vendor ID):" | head -5 || true
    if [[ "$addr" =~ ^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$ && ! "$addr" =~ ^(00[:-]){5}00$ ]]; then
        ok "Controller has a valid address (${addr})."
        return 0
    fi
    warn "Controller address is '${addr:-none}'."
    return 2
}

if [[ "$CHECK_ONLY" == "1" ]]; then
    report_controller
    exit $?
fi

[[ "${DRY_RUN:-0}" == "1" ]] || ensure_root "$0" "$@"

echo "=================================================================="
echo " Bluetooth Reset${DRY_RUN:+  (dry run)}"
echo "=================================================================="

confirm "This unpairs ALL Bluetooth devices. Continue?" || { echo "Aborted."; exit 0; }

PREF_FILES=()
for f in /Library/Preferences/com.apple.Bluetooth.plist \
         /var/root/Library/Preferences/com.apple.Bluetooth.plist \
         /Users/*/Library/Preferences/ByHost/com.apple.Bluetooth.*.plist; do
    [[ -f "$f" ]] && PREF_FILES+=("$f")
done

# 1. Back up
BACKUP_DIR="$(real_home)/Bluetooth_Backup_$(date +%Y%m%d_%H%M%S)"
info "[1/4] Backing up ${#PREF_FILES[@]} preference file(s) to ${BACKUP_DIR}"
if [[ ${#PREF_FILES[@]} -gt 0 ]]; then
    run mkdir -p "$BACKUP_DIR"
    for f in "${PREF_FILES[@]}"; do
        # Flatten the path into the file name so identical names do not collide
        run cp -p "$f" "${BACKUP_DIR}/$(echo "$f" | tr '/' '_' | sed 's/^_//')"
    done
fi

# 2. Stop the daemon (polite first, then force)
info "[2/4] Stopping bluetoothd"
run killall bluetoothd 2>/dev/null || true
if [[ "${DRY_RUN:-0}" != "1" ]]; then
    for _ in 1 2 3 4 5; do pgrep -x bluetoothd >/dev/null || break; sleep 1; done
    pgrep -x bluetoothd >/dev/null && { warn "bluetoothd did not exit; forcing"; killall -9 bluetoothd 2>/dev/null || true; }
fi

# 3. Remove preferences
info "[3/4] Removing preference files (this unpairs all devices)"
for f in "${PREF_FILES[@]+"${PREF_FILES[@]}"}"; do
    run rm -f "$f"
done

# 4. Restart and verify
info "[4/4] Restarting bluetoothd and checking the controller"
run launchctl kickstart -k system/com.apple.bluetoothd 2>/dev/null || true
if [[ "${DRY_RUN:-0}" != "1" ]]; then
    for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -x bluetoothd >/dev/null && break; sleep 1; done
    sleep 2
fi

echo "--------------------------------------------------"
rc=0
report_controller || rc=$?
echo "--------------------------------------------------"

if [[ "$rc" -ne 0 ]]; then
    echo "The controller still has no address. A daemon restart cannot fix that; it points to"
    echo "the firmware/kext side (IntelBluetoothFirmware, IntelBTPatcher, BlueToolFixup load order)."
    echo "Redeploy the EFI and reboot:  sudo ./scripts/deploy-efi.sh diskXsY  &&  sudo reboot"
fi
[[ ${#PREF_FILES[@]} -gt 0 ]] && echo "Old preferences saved in: ${BACKUP_DIR}"
exit "$rc"
