#!/usr/bin/env bash
# ==============================================================================
# ASUS ROG Strix GL503GE - Hackintosh macOS Sleep/Wake & Power Optimizer
# ==============================================================================
set -euo pipefail

echo "=================================================================="
echo " Applying optimal Hackintosh laptop power management settings..."
echo "=================================================================="

# Disable hibernation (Hackintoshes require pure S3 RAM sleep)
sudo pmset -a hibernatemode 0

# Disable deep standby timer and autopoweroff
sudo pmset -a standby 0
sudo pmset -a autopoweroff 0

# Disable Power Nap (background maintenance that wakes machine with screen off)
sudo pmset -a powernap 0

# Disable network keepalive wakeups while asleep (prevents DarkWake loops on Intel Wi-Fi)
sudo pmset -a tcpkeepalive 0

# Disable Wake on LAN / Magic Packet
sudo pmset -a womp 0

# Disable Proximity Wake
sudo pmset -a proximitywake 0

# Remove stale sleepimage to reclaim disk space
if [ -f /var/vm/sleepimage ]; then
    echo "Removing /var/vm/sleepimage..."
    sudo rm -f /var/vm/sleepimage
    sudo touch /var/vm/sleepimage
    sudo chflags uchg /var/vm/sleepimage
fi

echo "=================================================================="
echo " Current Power Settings (pmset -g):"
echo "=================================================================="
pmset -g
echo ""
echo "✅ Power management successfully optimized for S3 Sleep!"
