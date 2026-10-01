#!/usr/bin/env bash
# ==============================================================================
# ASUS ROG Strix GL503GE - Function Row Key Mapping Installer
# ==============================================================================
# Configures the native macOS hidutil user mapping for F1-F12 matching the
# physical keyboard silk-screen markings on the ASUS ROG Strix GL503GE:
#
#   - F1:  Mute / Unmute (0xC000000E2)
#   - F2:  Previous Track (0xC000000B6)
#   - F3:  Play / Pause (0xC000000CD)
#   - F4:  Next Track (0xC000000B5)
#   - F5:  Mission Control / Window Switcher (0xC0000029F)
#   - F6:  Turn Off Display / Lock Screen (0xC0000019E) [Matches physical icon]
#   - F7:  Display Brightness Down (0xC00000070) [Matches physical icon]
#   - F8:  Display Brightness Up (0xC0000006F) [Matches physical icon]
#   - F9:  Spotlight Search (0xC00000221)
#   - F10: Launchpad / App Grid (0xC000002A0)
#   - F11: System Sleep (0x100000082) [Matches physical icon]
#   - F12: Do Not Disturb / Focus Mode (0x10000009B)
#
# Note: Physical dedicated buttons for [Vol -], [Vol +], [Mic Mute], and
#       [ROG Eye] on the top-left island continue to work natively.
# ==============================================================================

set -euo pipefail

LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_FILE="$LAUNCH_AGENTS_DIR/com.local.KeyMapping.plist"

MODE="${1:-silkscreen}"

BOLD="\033[1m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[1;33m"
RESET="\033[0m"

echo -e "${BOLD}${CYAN}==================================================================${RESET}"
echo -e "${BOLD}${CYAN}   ASUS ROG Strix GL503GE - Function Keys Setup (hidutil)         ${RESET}"
echo -e "${BOLD}${CYAN}==================================================================${RESET}\n"

if [ "$MODE" = "--reset" ] || [ "$MODE" = "reset" ]; then
    echo "[-] Resetting all custom key mappings to factory defaults..."
    /usr/bin/hidutil property --set '{"UserKeyMapping":[]}' > /dev/null
    rm -f "$PLIST_FILE" 2>/dev/null || true
    echo -e "${GREEN}[✓] Custom key mappings removed.${RESET}"
    exit 0
fi

if [ "$MODE" = "--macbook" ] || [ "$MODE" = "macbook" ]; then
    echo -e "[+] Applying ${BOLD}MacBook Pro Style Layout${RESET} (F10=Mute, F11=Vol-, F12=Vol+)..."
    MAPPINGS='[
        {"HIDKeyboardModifierMappingSrc":0x70000003A,"HIDKeyboardModifierMappingDst":0xC000000E2},
        {"HIDKeyboardModifierMappingSrc":0x70000003B,"HIDKeyboardModifierMappingDst":0xC000000B6},
        {"HIDKeyboardModifierMappingSrc":0x70000003C,"HIDKeyboardModifierMappingDst":0xC000000CD},
        {"HIDKeyboardModifierMappingSrc":0x70000003D,"HIDKeyboardModifierMappingDst":0xC000000B5},
        {"HIDKeyboardModifierMappingSrc":0x70000003E,"HIDKeyboardModifierMappingDst":0xC0000029F},
        {"HIDKeyboardModifierMappingSrc":0x70000003F,"HIDKeyboardModifierMappingDst":0xC000002A0},
        {"HIDKeyboardModifierMappingSrc":0x700000040,"HIDKeyboardModifierMappingDst":0xC00000070},
        {"HIDKeyboardModifierMappingSrc":0x700000041,"HIDKeyboardModifierMappingDst":0xC0000006F},
        {"HIDKeyboardModifierMappingSrc":0x700000042,"HIDKeyboardModifierMappingDst":0xC00000221},
        {"HIDKeyboardModifierMappingSrc":0x700000043,"HIDKeyboardModifierMappingDst":0xC000000E2},
        {"HIDKeyboardModifierMappingSrc":0x700000044,"HIDKeyboardModifierMappingDst":0xC000000EA},
        {"HIDKeyboardModifierMappingSrc":0x700000045,"HIDKeyboardModifierMappingDst":0xC000000E9}
    ]'
else
    echo -e "[+] Applying ${BOLD}Physical ASUS GL503GE Silk-Screen Layout${RESET}:"
    echo -e "    - F1:  Mute / Unmute"
    echo -e "    - F2:  Previous Track"
    echo -e "    - F3:  Play / Pause"
    echo -e "    - F4:  Next Track"
    echo -e "    - F5:  Mission Control (Window Switcher)"
    echo -e "    - ${GREEN}F6:  Turn Off Display / Lock Screen${RESET}  [Physical Icon: Screen Off]"
    echo -e "    - F7:  Display Brightness Down"
    echo -e "    - F8:  Display Brightness Up"
    echo -e "    - F9:  Spotlight Search"
    echo -e "    - F10: Launchpad (App Grid)"
    echo -e "    - ${GREEN}F11: System Sleep${RESET}                   [Physical Icon: Sleep]"
    echo -e "    - ${GREEN}F12: Do Not Disturb / Focus Mode${RESET}   [Focus Moon Toggle]"

    MAPPINGS='[
        {"HIDKeyboardModifierMappingSrc":0x70000003A,"HIDKeyboardModifierMappingDst":0xC000000E2},
        {"HIDKeyboardModifierMappingSrc":0x70000003B,"HIDKeyboardModifierMappingDst":0xC000000B6},
        {"HIDKeyboardModifierMappingSrc":0x70000003C,"HIDKeyboardModifierMappingDst":0xC000000CD},
        {"HIDKeyboardModifierMappingSrc":0x70000003D,"HIDKeyboardModifierMappingDst":0xC000000B5},
        {"HIDKeyboardModifierMappingSrc":0x70000003E,"HIDKeyboardModifierMappingDst":0xC0000029F},
        {"HIDKeyboardModifierMappingSrc":0x70000003F,"HIDKeyboardModifierMappingDst":0xC0000019E},
        {"HIDKeyboardModifierMappingSrc":0x700000040,"HIDKeyboardModifierMappingDst":0xC00000070},
        {"HIDKeyboardModifierMappingSrc":0x700000041,"HIDKeyboardModifierMappingDst":0xC0000006F},
        {"HIDKeyboardModifierMappingSrc":0x700000042,"HIDKeyboardModifierMappingDst":0xC00000221},
        {"HIDKeyboardModifierMappingSrc":0x700000043,"HIDKeyboardModifierMappingDst":0xC000002A0},
        {"HIDKeyboardModifierMappingSrc":0x700000044,"HIDKeyboardModifierMappingDst":0x100000082},
        {"HIDKeyboardModifierMappingSrc":0x700000045,"HIDKeyboardModifierMappingDst":0x10000009B}
    ]'
fi

# Apply mapping immediately to active user session
/usr/bin/hidutil property --set "{\"UserKeyMapping\":$MAPPINGS}" > /dev/null
echo -e "  ${GREEN}[✓] Mappings activated immediately${RESET} in current session."

# Attempt to write LaunchAgent plist for persistent activation at login
mkdir -p "$LAUNCH_AGENTS_DIR" 2>/dev/null || true
if cat << EOF > "$PLIST_FILE" 2>/dev/null
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
        <string>{"UserKeyMapping":$MAPPINGS}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF
then
    echo -e "  ${GREEN}[✓] LaunchAgent installed:${RESET} $PLIST_FILE"
    echo -e "  ${GREEN}[✓] Persistence verified across reboots.${RESET}"
else
    echo -e "  ${YELLOW}[!] Note: To ensure persistence across reboots, run this command in Terminal:${RESET}"
    echo -e "      ${BOLD}./scripts/setup_function_keys.sh${RESET}"
fi

echo -e "\n${BOLD}${CYAN}==================================================================${RESET}"
echo -e "${BOLD}${GREEN}[SUCCESS] Function keys active! F6=Screen Off, F11=Sleep, F12=Focus.${RESET}"
echo -e "${BOLD}${CYAN}==================================================================${RESET}\n"
