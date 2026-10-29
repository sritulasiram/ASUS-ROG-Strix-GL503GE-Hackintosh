#!/usr/bin/env bash
# ==============================================================================
# ASUS ROG Strix GL503GE - Audio Health Check (Realtek ALC295 / AppleALC)
# ==============================================================================
# Read-only. Reports whether CoreAudio sees the internal speakers and microphone,
# whether the HDA codec matched, whether AppleALC is loaded and which layout is used.
#
#   check-audio.sh [--quiet]     --quiet prints only problems (for use in other scripts)
#
# Exit code: 0 healthy, 1 speakers missing or AppleALC not loaded.
# ==============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

QUIET=0
case "${1:-}" in
    --quiet|-q) QUIET=1 ;;
    -h|--help)  sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//' | grep -v '^=*$'; exit 0 ;;
    "") ;;
    *) die "Unknown option: $1" ;;
esac

fail=0
good() { [[ "$QUIET" == "1" ]] || echo -e "  ${GREEN}✓${NC} $*"; }
note() { echo -e "  ${YELLOW}!${NC} $*"; }
bad()  { echo -e "  ${RED}✗${NC} $*"; fail=1; }

[[ "$QUIET" == "1" ]] || echo -e "${BOLD}ASUS ROG Strix GL503GE - Audio Health Check${NC}\n"

AUDIO_OUTPUT=$(system_profiler SPAudioDataType 2>/dev/null || true)
if grep -q "Internal Speakers" <<<"$AUDIO_OUTPUT"; then
    good "Output: Internal Speakers"
else
    bad "Internal Speakers not detected by CoreAudio (check AppleALC / alcid / layout-id)."
fi

if grep -q "Internal Microphone" <<<"$AUDIO_OUTPUT"; then
    good "Input:  Internal Microphone"
else
    note "Internal Microphone not detected."
fi

# Capture output first: `grep -q` closing the pipe early would trip pipefail.
CODEC_INFO=$(ioreg -rxc AppleHDACodecGeneric 2>/dev/null || true)
if grep -qi "0x10ec0295" <<<"$CODEC_INFO"; then
    good "Codec:  Realtek ALC295 (0x10ec0295)"
else
    note "AppleHDACodecGeneric did not report 0x10ec0295."
fi

LOADED_KEXTS=$(kmutil showloaded --list-only 2>/dev/null || true)
if grep -q "as.vit9696.AppleALC" <<<"$LOADED_KEXTS"; then
    good "AppleALC.kext is loaded"
else
    bad "AppleALC.kext is not loaded."
fi

# Layout in use: AppleALC prefers alc-layout-id (device property) over alcid= in boot-args.
HDEF_INFO=$(ioreg -rxn HDEF 2>/dev/null || true)
ALC_HEX=$(awk '/"alc-layout-id"/ {gsub(/[<>]/, "", $NF); print $NF; exit}' <<<"$HDEF_INFO")
if [[ -n "$ALC_HEX" && ${#ALC_HEX} -ge 2 ]]; then
    # <0e000000> is little-endian: take the first byte
    good "Layout: alc-layout-id = $((16#${ALC_HEX:0:2}))"
fi

exit "$fail"
