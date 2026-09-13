#!/usr/bin/env bash
# ==============================================================================
# ASUS ROG Strix GL503GE - Function Row Key Mapping Installer
# ==============================================================================
# Configures the native macOS hidutil user mapping for F1-F12 matching the
# physical keyboard markings and macOS standards:
#   - F1:  Mute
#   - F2:  Previous Track
#   - F3:  Play / Pause
#   - F4:  Next Track
#   - F5:  Mission Control (Exposé)
#   - F6:  Launchpad
#   - F7:  Display Brightness Down
#   - F8:  Display Brightness Up
#   - F9:  Spotlight Search
#   - F10: Mute
#   - F11: Volume Down
#   - F12: Volume Up
# ==============================================================================

set -e

LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_FILE="$LAUNCH_AGENTS_DIR/com.local.KeyMapping.plist"

echo "=================================================================="
echo " Installing ASUS ROG GL503GE Function Keys (F1-F12)..."
echo "=================================================================="

mkdir -p "$LAUNCH_AGENTS_DIR"

cat << 'EOF' > "$PLIST_FILE"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.local.KeyMapping</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/hidutil</string>
        <string>property</string>
        <string>--set</string>
        <string>{"UserKeyMapping":[
            {"HIDKeyboardModifierMappingSrc":0x70000003A,"HIDKeyboardModifierMappingDst":0xC000000E2},
            {"HIDKeyboardModifierMappingSrc":0x70000003B,"HIDKeyboardModifierMappingDst":0xC000000B6},
            {"HIDKeyboardModifierMappingSrc":0x70000003C,"HIDKeyboardModifierMappingDst":0xC000000CD},
            {"HIDKeyboardModifierMappingSrc":0x70000003D,"HIDKeyboardModifierMappingDst":0xC000000B5},
            {"HIDKeyboardModifierMappingSrc":0x70000003E,"HIDKeyboardModifierMappingDst":0xC0000029F},
            {"HIDKeyboardModifierMappingSrc":0x70000003F,"HIDKeyboardModifierMappingDst":0xC000002A0},
            {"HIDKeyboardModifierMappingSrc":0x700000040,"HIDKeyboardModifierMappingDst":0xC00000070},
            {"HIDKeyboardModifierMappingSrc":0x700000041,"HIDKeyboardModifierMappingDst":0xC0000006F},
            {"HIDKeyboardModifierMappingSrc":0x700000042,"HIDKeyboardModifierMappingDst":0x7000000A4},
            {"HIDKeyboardModifierMappingSrc":0x700000043,"HIDKeyboardModifierMappingDst":0xC000000E2},
            {"HIDKeyboardModifierMappingSrc":0x700000044,"HIDKeyboardModifierMappingDst":0xC000000EA},
            {"HIDKeyboardModifierMappingSrc":0x700000045,"HIDKeyboardModifierMappingDst":0xC000000E9}
        ]}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

# Apply mapping immediately to active session
/usr/bin/hidutil property --set '{"UserKeyMapping":[
    {"HIDKeyboardModifierMappingSrc":0x70000003A,"HIDKeyboardModifierMappingDst":0xC000000E2},
    {"HIDKeyboardModifierMappingSrc":0x70000003B,"HIDKeyboardModifierMappingDst":0xC000000B6},
    {"HIDKeyboardModifierMappingSrc":0x70000003C,"HIDKeyboardModifierMappingDst":0xC000000CD},
    {"HIDKeyboardModifierMappingSrc":0x70000003D,"HIDKeyboardModifierMappingDst":0xC000000B5},
    {"HIDKeyboardModifierMappingSrc":0x70000003E,"HIDKeyboardModifierMappingDst":0xC0000029F},
    {"HIDKeyboardModifierMappingSrc":0x70000003F,"HIDKeyboardModifierMappingDst":0xC000002A0},
    {"HIDKeyboardModifierMappingSrc":0x700000040,"HIDKeyboardModifierMappingDst":0xC00000070},
    {"HIDKeyboardModifierMappingSrc":0x700000041,"HIDKeyboardModifierMappingDst":0xC0000006F},
    {"HIDKeyboardModifierMappingSrc":0x700000042,"HIDKeyboardModifierMappingDst":0x7000000A4},
    {"HIDKeyboardModifierMappingSrc":0x700000043,"HIDKeyboardModifierMappingDst":0xC000000E2},
    {"HIDKeyboardModifierMappingSrc":0x700000044,"HIDKeyboardModifierMappingDst":0xC000000EA},
    {"HIDKeyboardModifierMappingSrc":0x700000045,"HIDKeyboardModifierMappingDst":0xC000000E9}
]}' > /dev/null

echo "[+] LaunchAgent installed to: $PLIST_FILE"
echo "[+] Mappings activated immediately."
echo "[+] Persistent across reboots."
echo "=================================================================="
echo "[SUCCESS] Function keys (F1-F12) are now fully functional!"
echo "=================================================================="
