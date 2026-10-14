#!/usr/bin/env bash
# ==============================================================================
# ASUS ROG Strix GL503GE - Intel Bluetooth Reset & Diagnostic Tool
# ==============================================================================
# Resets stale Bluetooth daemon caches, restarts the macOS Bluetooth subsystem,
# and verifies controller hardware communication on internal port HS14.
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}==================================================================${NC}"
echo -e "${BLUE} ASUS ROG Strix GL503GE — Bluetooth Reset & Diagnostics          ${NC}"
echo -e "${BLUE}==================================================================${NC}"

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Error: This script must be run with sudo privileges.${NC}"
    echo "Please run: sudo $0"
    exit 1
fi

if [[ "${1:-}" != "--yes" ]]; then
    read -r -p "This unpairs ALL Bluetooth devices. Continue? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
fi

echo -e "${BLUE}[1/4] Stopping Bluetooth daemon (bluetoothd)...${NC}"
killall -9 bluetoothd 2>/dev/null || true
sleep 1

echo -e "${YELLOW}[2/4] Removing Bluetooth preferences and caches (this UNPAIRS all devices)...${NC}"
rm -f /Library/Preferences/com.apple.Bluetooth.plist 2>/dev/null || true
rm -f /Users/*/Library/Preferences/ByHost/com.apple.Bluetooth.*.plist 2>/dev/null || true
rm -f /var/root/Library/Preferences/com.apple.Bluetooth.plist 2>/dev/null || true

echo -e "${BLUE}[3/4] Restarting system Bluetooth daemon...${NC}"
launchctl kickstart -k system/com.apple.bluetoothd 2>/dev/null || true
sleep 2

echo -e "${BLUE}[4/4] Checking live Bluetooth Controller state...${NC}"
echo "--------------------------------------------------"
system_profiler SPBluetoothDataType | grep -E "(Bluetooth Controller|Address|State|Chipset|Vendor ID)" || true
echo "--------------------------------------------------"

echo ""
echo -e "${GREEN}✅ Bluetooth daemon reset complete!${NC}"
echo "Note: If the controller still shows Address: NULL, deploy the updated EFI"
echo "with the corrected kext load order and reboot:"
echo "    sudo ./scripts/deploy_to_esp.sh"
echo "    sudo reboot"
echo ""
