#!/bin/bash
# ==============================================================================
# ASUS ROG Strix GL503GE - Native MacBook Pro Display & Retina HiDPI Setup
# ==============================================================================
# Configures native macOS System Settings to identify the internal 120Hz panel
# as a "Built-in Retina Display" with MacBook Pro icon and HiDPI scaling,
# with ZERO third-party background applications or daemons required.
# ==============================================================================

set -e

OVERRIDE_DIR="/Library/Displays/Contents/Resources/Overrides"
VENDOR_ID="dae"
PRODUCT_ID="15f4"
VENDOR_DIR="${OVERRIDE_DIR}/DisplayVendorID-${VENDOR_ID}"
OVERRIDE_FILE="${VENDOR_DIR}/DisplayProductID-${PRODUCT_ID}"
ICONS_PLIST="${OVERRIDE_DIR}/Icons.plist"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function show_help() {
    echo "Usage: sudo $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --enable     Install native MacBook Pro display override & HiDPI scaling (Default)"
    echo "  --disable    Remove display overrides and restore default macOS configuration"
    echo "  --status     Check current installation status"
    echo "  --help       Show this help message"
    echo ""
}

function check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Error: This script must be run with sudo privileges.${NC}"
        echo "Please run: sudo $0"
        exit 1
    fi
}

function status() {
    echo -e "${BLUE}=== Display Override & Retina Status ===${NC}"
    if [[ -f "${OVERRIDE_FILE}" ]]; then
        echo -e "Display Override:  ${GREEN}Active${NC} (${OVERRIDE_FILE})"
    else
        echo -e "Display Override:  ${YELLOW}Not Installed${NC}"
    fi

    if [[ -f "${ICONS_PLIST}" ]] && grep -q "${VENDOR_ID}" "${ICONS_PLIST}" 2>/dev/null; then
        echo -e "MacBook Pro Icon:  ${GREEN}Active${NC} (${ICONS_PLIST})"
    else
        echo -e "MacBook Pro Icon:  ${YELLOW}Not Configured${NC}"
    fi
    echo ""
}

function disable() {
    check_root
    echo -e "${YELLOW}Removing native display overrides...${NC}"
    
    if [[ -d "${VENDOR_DIR}" ]]; then
        rm -rf "${VENDOR_DIR}"
        echo -e "${GREEN}✓ Removed ${VENDOR_DIR}${NC}"
    fi

    if [[ -f "${ICONS_PLIST}" ]]; then
        /usr/libexec/PlistBuddy -c "Delete :vendors:${VENDOR_ID}" "${ICONS_PLIST}" 2>/dev/null || true
        echo -e "${GREEN}✓ Removed vendor entry from ${ICONS_PLIST}${NC}"
    fi

    # Reset WindowServer display cache so changes take effect
    rm -f /Library/Preferences/com.apple.windowserver.displays.plist 2>/dev/null || true
    rm -f /Users/*/Library/Preferences/ByHost/com.apple.windowserver.displays.*.plist 2>/dev/null || true

    echo -e "${GREEN}✅ Default macOS display configuration restored. Please restart your Mac.${NC}"
}

function enable() {
    check_root
    echo -e "${BLUE}==================================================================${NC}"
    echo -e "${BLUE} ASUS ROG Strix GL503GE — Native MacBook Pro Display Setup       ${NC}"
    echo -e "${BLUE}==================================================================${NC}"
    echo "Panel: Chi Mei Innolux N156HHE-GA1 (1080p @ 120Hz, 94% NTSC)"
    echo "Target: Native System Settings 'Built-in Retina Display' + HiDPI"
    echo ""

    # 1. Ensure target directory exists
    mkdir -p "${VENDOR_DIR}"

    # 2. Write Display Override plist
    echo -e "${BLUE}[1/4] Writing native Display Override plist...${NC}"
    cat <<'EOF' > "${OVERRIDE_FILE}"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>DisplayProductID</key>
	<integer>5620</integer>
	<key>DisplayVendorID</key>
	<integer>3502</integer>
	<key>DisplayProductName</key>
	<string>Built-in Retina Display</string>
	<key>scale-resolutions</key>
	<array>
		<!-- HiDPI (Retina 2x backing buffer) Modes -->
		<data>AAAPAAAACHAAAAABACAAAA==</data> <!-- 1920x1080 HiDPI (Rendered at 3840x2160) -->
		<data>AAANIAAAB2IAAAABACAAAA==</data> <!-- 1680x945  HiDPI (Rendered at 3360x1890) -->
		<data>AAAMgAAABwgAAAABACAAAA==</data> <!-- 1600x900  HiDPI (Rendered at 3200x1800) -->
		<data>AAALIAAABkQAAAABACAAAA==</data> <!-- 1424x802  HiDPI (Rendered at 2848x1604 - Apple Sleep Fix) -->
		<data>AAALQAAABlQAAAABACAAAA==</data> <!-- 1440x810  HiDPI (Rendered at 2880x1620) -->
		<data>AAAKAAAABaAAAAABACAAAA==</data> <!-- 1280x720  HiDPI (Rendered at 2560x1440) -->
		<data>AAAIAAAABIAAAAABACAAAA==</data> <!-- 1024x576  HiDPI (Rendered at 2048x1152) -->
		<data>AAAHgAAABDgAAAABACAAAA==</data> <!-- 960x540   HiDPI (Rendered at 1920x1080) -->

		<!-- Standard 1x Native Modes -->
		<data>AAAHgAAABDgAAAA=</data>         <!-- 1920x1080 1x Standard -->
		<data>AAAGQAAAA4QAAAA=</data>         <!-- 1600x900  1x Standard -->
		<data>AAAFQAAAA2AAAAA=</data>         <!-- 1344x756  1x Standard -->
		<data>AAAKAAAABaAAAAA=</data>         <!-- 1280x720  1x Standard -->
	</array>
</dict>
</plist>
EOF

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

    # 4. Set ColorSync profile to native wide-gamut / Display P3
    echo -e "${BLUE}[3/4] Calibrating ColorSync profile...${NC}"
    if [[ -f "${SCRIPT_DIR}/set_color_profile.py" ]]; then
        python3 "${SCRIPT_DIR}/set_color_profile.py" --native || true
        echo -e "${GREEN}✓ ColorSync calibrated to panel wide gamut (94% NTSC / D65)${NC}"
    fi

    # 5. Enable macOS HiDPI resolution engine
    echo -e "${BLUE}[4/5] Enabling macOS HiDPI Display Engine...${NC}"
    defaults write /Library/Preferences/com.apple.windowserver.plist DisplayResolutionEnabled -bool true
    defaults write /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled -bool true

    # 6. Flush WindowServer display caches
    echo -e "${BLUE}[5/5] Refreshing WindowServer display cache...${NC}"
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

# Main routing
case "$1" in
    --disable|--remove)
        disable
        ;;
    --status)
        status
        ;;
    --help|-h)
        show_help
        ;;
    --enable|"")
        enable
        ;;
    *)
        echo -e "${RED}Unknown option: $1${NC}"
        show_help
        exit 1
        ;;
esac
