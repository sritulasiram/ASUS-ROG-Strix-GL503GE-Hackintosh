#!/bin/bash
# ==============================================================================
# ASUS ROG Strix GL503GE - Display Manager
# ==============================================================================
# One entry point for the internal 120Hz panel (Chi Mei N156HHE-GA1, IPS, ~100% sRGB):
#   setup    Native "Built-in Retina Display" override, MacBook Pro icon, HiDPI modes
#   revert   Remove that override (restores the default macOS display config)
#   look     Dark mode + reduced transparency + sRGB profile (hides IPS backlight glow)
#   profile  Switch/show the ColorSync profile (native / sRGB / P3 / custom ICC)
#   status   Show override, icon and appearance state
# No third-party background apps or daemons are required.
# ==============================================================================

set -euo pipefail

OVERRIDE_DIR="/Library/Displays/Contents/Resources/Overrides"
VENDOR_ID="dae"
PRODUCT_ID="15f4"
VENDOR_DIR="${OVERRIDE_DIR}/DisplayVendorID-${VENDOR_ID}"
OVERRIDE_FILE="${VENDOR_DIR}/DisplayProductID-${PRODUCT_ID}"
ICONS_PLIST="${OVERRIDE_DIR}/Icons.plist"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"


function show_help() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  setup                 Install display override, icon and HiDPI modes (uses sudo)"
    echo "  revert                Remove the display override (uses sudo)"
    echo "  look [--off]          Apply (or undo) dark mode, reduced transparency, sRGB profile"
    echo "  profile <option>      --srgb | --native | --p3 | --custom file.icc | --status"
    echo "  status                Show override, icon and appearance state"
    echo "  help                  Show this help message"
    echo ""
    echo "Recommended order: setup (reboot), then look."
    echo ""
}

function check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Error: this command must be run with sudo privileges.${NC}"
        exit 1
    fi
}

function status() {
    echo -e "${BLUE}=== Display Status ===${NC}"
    if [[ -f "${OVERRIDE_FILE}" ]]; then
        # Compare the installed override with the repo copy (key order/format independent)
        if diff -q <(plutil -convert xml1 -o - "${OVERRIDE_FILE}" 2>/dev/null) \
                   <(plutil -convert xml1 -o - "${SCRIPT_DIR}/lib/display-override.plist") >/dev/null 2>&1; then
            echo -e "Display Override:  ${GREEN}Active, up to date${NC}"
        else
            echo -e "Display Override:  ${YELLOW}Installed but differs from the repo copy${NC} (run: ./display.sh setup, then reboot)"
        fi
    else
        echo -e "Display Override:  ${YELLOW}Not Installed${NC} (run: ./display.sh setup)"
    fi

    if [[ -f "${ICONS_PLIST}" ]] && grep -q "${VENDOR_ID}" "${ICONS_PLIST}" 2>/dev/null; then
        echo -e "MacBook Pro Icon:  ${GREEN}Active${NC}"
    else
        echo -e "MacBook Pro Icon:  ${YELLOW}Not Configured${NC}"
    fi

    if [[ "$(defaults read -g AppleInterfaceStyle 2>/dev/null || true)" == "Dark" ]]; then
        echo -e "Appearance:        ${GREEN}Dark${NC}"
    else
        echo -e "Appearance:        ${YELLOW}Light${NC}"
    fi

    if [[ "$(defaults read com.apple.universalaccess reduceTransparency 2>/dev/null || true)" == "1" ]]; then
        echo -e "Transparency:      ${GREEN}Reduced${NC} (setting; may need a re-login to show)"
    else
        echo -e "Transparency:      ${YELLOW}Normal${NC}"
    fi

    local prof
    prof="$("${SCRIPT_DIR}/lib/colorsync.py" --status 2>&1 | grep -A1 CustomProfiles | grep -o 'file://[^"]*' | head -1 | xargs -I{} basename {} || true)"
    prof="${prof//%20/ }"
    if [[ -n "$prof" ]]; then
        echo -e "Colour profile:    ${GREEN}${prof}${NC}"
    else
        echo -e "Colour profile:    ${YELLOW}factory (native EDID)${NC}"
    fi
    echo ""
}

function revert() {
    check_root
    echo -e "${YELLOW}Removing native display overrides...${NC}"
    
    if [[ -f "${OVERRIDE_FILE}" || -L "${OVERRIDE_FILE}.plist" ]]; then
        rm -f "${OVERRIDE_FILE}" "${OVERRIDE_FILE}.plist"
        rmdir "${VENDOR_DIR}" 2>/dev/null || true
        echo -e "${GREEN}✓ Removed ${OVERRIDE_FILE}${NC}"
    fi

    if [[ -f "${ICONS_PLIST}" ]]; then
        /usr/libexec/PlistBuddy -c "Delete :vendors:${VENDOR_ID}" "${ICONS_PLIST}" 2>/dev/null || true
        echo -e "${GREEN}✓ Removed vendor entry from ${ICONS_PLIST}${NC}"
    fi

    # Reset WindowServer display cache so changes take effect
    rm -f /Library/Preferences/com.apple.windowserver.displays.plist 2>/dev/null || true
    rm -f /Users/*/Library/Preferences/ByHost/com.apple.windowserver.displays.*.plist 2>/dev/null || true

    echo -e "${GREEN}✅ Default macOS display configuration restored. Please restart your Mac.${NC}"
    echo "Appearance and colour profile are separate: run ./display.sh look --off to undo those."
}

function setup() {
    check_root
    echo -e "${BLUE}==================================================================${NC}"
    echo -e "${BLUE} ASUS ROG Strix GL503GE — Native MacBook Pro Display Setup       ${NC}"
    echo -e "${BLUE}==================================================================${NC}"
    echo "Panel: Chi Mei Innolux N156HHE-GA1 (1080p @ 120Hz, ~100% sRGB)"
    echo "Target: Native System Settings 'Built-in Retina Display' + HiDPI"
    echo ""

    # 1. Ensure target directory exists
    mkdir -p "${VENDOR_DIR}"

    # 2. Write Display Override plist
    echo -e "${BLUE}[1/4] Writing native Display Override plist...${NC}"
    cp "${SCRIPT_DIR}/lib/display-override.plist" "${OVERRIDE_FILE}"
    plutil -lint "${OVERRIDE_FILE}" >/dev/null || { echo -e "${RED}Invalid override plist${NC}"; exit 1; }

    # Create .plist named symlink for broad macOS compatibility
    ln -sf "DisplayProductID-${PRODUCT_ID}" "${VENDOR_DIR}/DisplayProductID-${PRODUCT_ID}.plist"
    chmod 644 "${OVERRIDE_FILE}"
    echo -e "${GREEN}✓ Created: ${OVERRIDE_FILE}${NC}"

    # 3. Configure MacBook Pro Display Icon in Icons.plist
    echo -e "${BLUE}[2/4] Registering MacBook Pro hardware icon...${NC}"
    
    # Locate best available system MacBook Pro Retina icon
    MBP_ICON="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/com.apple.macbookpro-15-retina-display.icns"
    if [[ ! -f "${MBP_ICON}" ]]; then
        MBP_ICON="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/com.apple.macbookpro-16-space-gray.icns"
    fi
    if [[ ! -f "${MBP_ICON}" ]]; then
        MBP_ICON="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/com.apple.macbookpro-13-retina-display.icns"
    fi
    if [[ ! -f "${MBP_ICON}" ]]; then
        echo -e "${YELLOW}! No MacBook Pro icon found in CoreTypes; the generic display icon will be used.${NC}"
    fi

    if [[ ! -f "${ICONS_PLIST}" ]]; then
        cat <<'EOF' > "${ICONS_PLIST}"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>vendors</key>
	<dict/>
</dict>
</plist>
EOF
    fi

    # Add vendor and product dictionary in Icons.plist
    /usr/libexec/PlistBuddy -c "Add :vendors:${VENDOR_ID} dict" "${ICONS_PLIST}" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :vendors:${VENDOR_ID}:products dict" "${ICONS_PLIST}" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Delete :vendors:${VENDOR_ID}:products:${PRODUCT_ID}" "${ICONS_PLIST}" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :vendors:${VENDOR_ID}:products:${PRODUCT_ID} dict" "${ICONS_PLIST}"
    /usr/libexec/PlistBuddy -c "Add :vendors:${VENDOR_ID}:products:${PRODUCT_ID}:display-icon string ${MBP_ICON}" "${ICONS_PLIST}"
    /usr/libexec/PlistBuddy -c "Add :vendors:${VENDOR_ID}:products:${PRODUCT_ID}:product-icon string ${MBP_ICON}" "${ICONS_PLIST}"
    /usr/libexec/PlistBuddy -c "Add :vendors:${VENDOR_ID}:products:${PRODUCT_ID}:resolution-preview-x real 19" "${ICONS_PLIST}"
    /usr/libexec/PlistBuddy -c "Add :vendors:${VENDOR_ID}:products:${PRODUCT_ID}:resolution-preview-y real 17" "${ICONS_PLIST}"
    /usr/libexec/PlistBuddy -c "Add :vendors:${VENDOR_ID}:products:${PRODUCT_ID}:resolution-preview-width real 80" "${ICONS_PLIST}"
    /usr/libexec/PlistBuddy -c "Add :vendors:${VENDOR_ID}:products:${PRODUCT_ID}:resolution-preview-height real 51" "${ICONS_PLIST}"
    chmod 644 "${ICONS_PLIST}"
    echo -e "${GREEN}✓ Mapped display icon to: ${MBP_ICON}${NC}"

    # 3. Enable macOS HiDPI resolution engine
    echo -e "${BLUE}[3/4] Enabling macOS HiDPI Display Engine...${NC}"
    defaults write /Library/Preferences/com.apple.windowserver.plist DisplayResolutionEnabled -bool true

    # 4. Flush WindowServer display caches
    echo -e "${BLUE}[4/4] Refreshing WindowServer display cache...${NC}"
    rm -f /Library/Preferences/com.apple.windowserver.displays.plist 2>/dev/null || true
    rm -f /Users/*/Library/Preferences/ByHost/com.apple.windowserver.displays.*.plist 2>/dev/null || true

    echo ""
    echo -e "${GREEN}==================================================================${NC}"
    echo -e "${GREEN} ✅ Native MacBook Pro Display Setup Complete!                    ${NC}"
    echo -e "${GREEN}==================================================================${NC}"
    echo "To activate:"
    echo "  1. Restart your Mac (or log out and log back in)."
    echo "  2. Open System Settings > Displays."
    echo "  3. You will see:"
    echo "     • Authentic MacBook Pro display icon."
    echo "     • 'Built-in Retina Display' name."
    echo "     • Native HiDPI scaling resolutions (e.g. 1920x1080 HiDPI, 1680x945 HiDPI)."
    echo "     • 100% native macOS rendering running at hardware 120Hz."
    echo "     • Zero background apps or memory overhead."
    echo ""
}

function look() {
    local on=true
    [[ "${1:-}" == "--off" ]] && on=false

    if ! osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to ${on}" 2>/dev/null; then
        echo -e "${YELLOW}Could not change appearance (grant Terminal Automation access); set it in System Settings > Appearance.${NC}"
    fi
    # May be blocked by macOS privacy protections; fall back to a manual hint.
    if ! defaults write com.apple.universalaccess reduceTransparency -bool "${on}" 2>/dev/null; then
        echo -e "${YELLOW}Could not set Reduce transparency; set it in System Settings > Accessibility > Display.${NC}"
    fi

    if [[ "${on}" == true ]]; then
        "${SCRIPT_DIR}/lib/colorsync.py" --srgb 2>&1 | grep -E "✅|❌" || true
        echo "Done. Also use a black wallpaper and keep brightness around 30-50% in dim rooms."
    else
        "${SCRIPT_DIR}/lib/colorsync.py" --native 2>&1 | grep -E "✅|❌" || true
        echo "Restored defaults."
    fi
}

# Main routing
cmd="${1:-help}"
[[ $# -gt 0 ]] && shift

case "${cmd}" in
    setup|revert)
        # Writes to /Library; re-run through sudo. look/profile act on the current user.
        [[ $EUID -eq 0 ]] || exec sudo "$0" "${cmd}" "$@"
        "${cmd}"
        ;;
    look)    look "$@" ;;
    profile) "${SCRIPT_DIR}/lib/colorsync.py" "$@" ;;
    status)  status ;;
    help|-h|--help) show_help ;;
    *)
        echo -e "${RED}Unknown command: ${cmd}${NC}"
        show_help
        exit 1
        ;;
esac
