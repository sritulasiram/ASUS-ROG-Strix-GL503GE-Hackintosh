#!/usr/bin/env bash
# ==============================================================================
# ASUS ROG Strix GL503GE - Function Row (F1-F12) Mapping via hidutil
# ==============================================================================
#   setup-fnkeys.sh [--silkscreen]   match the printed icons (default)
#   setup-fnkeys.sh --macbook        MacBook-style row (F10 Mute, F11 Vol-, F12 Vol+)
#   setup-fnkeys.sh --status         show the active F-key mappings and the LaunchAgent
#   setup-fnkeys.sh --reset          remove only the F1-F12 mappings and the LaunchAgent
#   add --dry-run to print what would be applied without changing anything
#
# Mappings are applied to the current session and persisted with a LaunchAgent.
# Other (non F1-F12) hidutil mappings you may have are preserved.
#
# Silk-screen layout:
#   F1 Mute  F2 Prev  F3 Play/Pause  F4 Next  F5 Mission Control  F6 Display off/lock
#   F7 Brightness-  F8 Brightness+  F9 Spotlight  F10 Launchpad  F11 Sleep  F12 Do Not Disturb
# The dedicated Vol-/Vol+/Mic/ROG keys are separate hardware and work natively.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_FILE="$LAUNCH_AGENTS_DIR/com.local.KeyMapping.plist"

# HID usage page 0x07 (keyboard) F1..F12 = 0x70000003A..0x700000045
F1_USAGE=$((0x70000003A))
F12_USAGE=$((0x700000045))

# Destination usages, F1..F12 (consumer page 0x0C, generic desktop 0x01)
SILKSCREEN_DST=(0xC000000E2 0xC000000B6 0xC000000CD 0xC000000B5 0xC0000029F 0xC0000019E
                0xC00000070 0xC0000006F 0xC00000221 0xC000002A0 0x100000082 0x10000009B)
MACBOOK_DST=(0xC000000E2 0xC000000B6 0xC000000CD 0xC000000B5 0xC0000029F 0xC000002A0
             0xC00000070 0xC0000006F 0xC00000221 0xC000000E2 0xC000000EA 0xC000000E9)

usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//' | grep -v '^=*$'; }

MODE="silkscreen"
for arg in "$@"; do
    case "$arg" in
        --silkscreen|silkscreen) MODE="silkscreen" ;;
        --macbook|macbook)       MODE="macbook" ;;
        --reset|reset)           MODE="reset" ;;
        --status)                MODE="status" ;;
        --dry-run)               DRY_RUN=1 ;;
        -h|--help)               usage; exit 0 ;;
        *) usage >&2; die "Unknown option: $arg" ;;
    esac
done

# Current mappings as "src dst" decimal pairs (hidutil prints an old-style plist).
current_pairs() {
    /usr/bin/hidutil property --get UserKeyMapping 2>/dev/null | awk '
        /HIDKeyboardModifierMappingDst/ {gsub(/[^0-9]/, "", $3); dst=$3}
        /HIDKeyboardModifierMappingSrc/ {gsub(/[^0-9]/, "", $3); print $3, dst}'
}

# JSON entries for mappings that are NOT ours (src outside F1..F12)
foreign_entries() {
    current_pairs | awk -v lo="$F1_USAGE" -v hi="$F12_USAGE" '
        $1 < lo || $1 > hi {printf "{\"HIDKeyboardModifierMappingSrc\":%s,\"HIDKeyboardModifierMappingDst\":%s}\n", $1, $2}'
}

# Join lines of JSON entries with commas into one array
join_json() { paste -sd, - ; }

our_entries() { # dst array name
    local -a dst=("${!1}")
    local i
    for i in "${!dst[@]}"; do
        printf '{"HIDKeyboardModifierMappingSrc":%d,"HIDKeyboardModifierMappingDst":%d}\n' \
            $((F1_USAGE + i)) $((dst[i]))
    done
}

apply_mapping() { # json array body
    local json="{\"UserKeyMapping\":[$1]}"
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
        echo "  + hidutil property --set '$json'" >&2
    else
        /usr/bin/hidutil property --set "$json" >/dev/null
    fi
    echo "$json"
}

write_agent() { # full json
    if [[ "${DRY_RUN:-0}" == "1" ]]; then echo "  + write $PLIST_FILE"; return 0; fi
    mkdir -p "$LAUNCH_AGENTS_DIR"
    cat > "$PLIST_FILE" <<EOF
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
        <string>$1</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF
    plutil -lint "$PLIST_FILE" >/dev/null || die "Generated an invalid LaunchAgent plist: $PLIST_FILE"
}

status() {
    local n
    n=$(current_pairs | awk -v lo="$F1_USAGE" -v hi="$F12_USAGE" '$1 >= lo && $1 <= hi' | wc -l | tr -d ' ')
    echo "Active F1-F12 mappings: ${n}/12"
    current_pairs | awk -v lo="$F1_USAGE" -v hi="$F12_USAGE" '$1 >= lo && $1 <= hi {printf "  F%d -> 0x%X\n", $1 - lo + 1, $2}'
    [[ -f "$PLIST_FILE" ]] && echo "LaunchAgent: installed ($PLIST_FILE)" || echo "LaunchAgent: not installed (mappings last until logout/reboot)"
}

case "$MODE" in
    status) status ;;
    reset)
        info "Removing F1-F12 mappings (other mappings are kept)..."
        rest="$(foreign_entries | join_json)"
        apply_mapping "$rest" >/dev/null
        [[ "${DRY_RUN:-0}" == "1" ]] || rm -f "$PLIST_FILE"
        if [[ "${DRY_RUN:-0}" == "1" ]]; then echo "Dry run: nothing was changed."; else ok "F-key mappings removed."; fi
        ;;
    silkscreen|macbook)
        if [[ "$MODE" == "macbook" ]]; then dst=("${MACBOOK_DST[@]}"); else dst=("${SILKSCREEN_DST[@]}"); fi
        info "Applying the ${MODE} layout..."
        ours="$(our_entries dst[@])"
        foreign="$(foreign_entries)"
        body="$(printf '%s\n%s\n' "$foreign" "$ours" | sed '/^$/d' | join_json)"
        full="$(apply_mapping "$body" | tail -1)"
        write_agent "$full"
        if [[ "${DRY_RUN:-0}" == "1" ]]; then echo "Dry run: nothing was changed."; else ok "Mappings applied to this session and persisted at every login."; fi
        ;;
esac
