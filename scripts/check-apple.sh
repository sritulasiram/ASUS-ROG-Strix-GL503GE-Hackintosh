#!/usr/bin/env bash
# ==============================================================================
# ASUS ROG Strix GL503GE - Apple Feature Check (read-only)
# ==============================================================================
# Probes what can be verified from the command line: SMBIOS, iCloud/iMessage
# prerequisites, Bluetooth, Wi-Fi, AirPlay Receiver, Continuity Camera, graphics,
# AWDL, sleep/wake. Prints no serials, IDs, e-mail addresses or account details.
#
#   check-apple.sh           fast checks
#   check-apple.sh --deep    also scan the last 3 h of logs for iMessage registration
#                            and test hardware video decode (compiles a tiny test once)
#
#   ✓ verified   ✗ broken   ! worth a look   ? cannot be verified from here
# Exit code: 0 unless a core prerequisite (✗) is broken.
# ==============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

DEEP=0
case "${1:-}" in
    --deep) DEEP=1 ;;
    -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//' | grep -v '^=*$'; exit 0 ;;
    "") ;;
    *) die "Unknown option: $1" ;;
esac

fail=0
good() { echo -e "  ${GREEN}✓${NC} $*"; }
bad()  { echo -e "  ${RED}✗${NC} $*"; fail=1; }
note() { echo -e "  ${YELLOW}!${NC} $*"; }
unk()  { echo -e "  ${CYAN}?${NC} $*"; }
head_() { echo -e "\n${BOLD}$*${NC}"; }

echo -e "${BOLD}ASUS ROG Strix GL503GE - Apple Feature Check${NC} (macOS $(sw_vers -productVersion))"

# ---- Platform -----------------------------------------------------------------
head_ "Platform"
model="$(system_profiler SPHardwareDataType 2>/dev/null | awk -F': ' '/Model Identifier/ {print $2}')"
if [[ "$model" == "MacBookPro16,4" ]]; then good "SMBIOS: $model"; else note "SMBIOS: ${model:-unknown} (this EFI is built for MacBookPro16,4)"; fi
sip="$(csrutil status 2>&1 | head -1 | sed -e 's/^System Integrity Protection status: //' -e 's/\.$//')"
note "SIP: ${sip} (custom is expected when OCLP-Mod root patches are used)"

# ---- Apple ID / iMessage prerequisites -----------------------------------------
head_ "Apple ID, iMessage & FaceTime"
accounts="$(defaults read MobileMeAccounts Accounts 2>/dev/null | grep -c AccountID || true)"
if [[ "${accounts:-0}" -ge 1 ]]; then good "iCloud: signed in (${accounts} account)"; else note "iCloud: no account signed in"; fi

# Capture command output before grep -q: an early-closing grep would trip pipefail.
en0_info="$(ioreg -rxn en0 2>/dev/null || true)"
if grep -q '"IOBuiltin" = Yes' <<<"$en0_info"; then good "en0 is flagged built-in (required for iMessage)"; else bad "en0 is not flagged built-in (set IOBuiltin / device-properties for the Ethernet controller)"; fi

nvram_ok=1
for k in ROM MLB; do
    nvram "4D1EDE05-38C7-4A6A-9CC6-4BCCA8B38C14:${k}" >/dev/null 2>&1 || { bad "NVRAM ${k} is missing"; nvram_ok=0; }
done
[[ "$nvram_ok" == "1" ]] && good "NVRAM ROM and MLB are set (values not shown)"

if pgrep -x identityservicesd >/dev/null && pgrep -x imagent >/dev/null; then
    good "identityservicesd and imagent are running"
else
    note "identityservicesd / imagent not running"
fi

if [[ "$DEEP" == "1" ]]; then
    reg="$(/usr/bin/log show --last 3h --style compact --predicate 'process == "identityservicesd"' 2>/dev/null | grep -c "IDS:Registration.*=> Registered" || true)"
    if [[ "${reg:-0}" -gt 0 ]]; then good "IDS registration: 'Registered' logged ${reg} time(s) in the last 3 h"; else unk "No IDS 'Registered' line in the last 3 h (try again after signing in or toggling iMessage)"; fi
else
    unk "IDS registration log scan skipped (use --deep)"
fi
unk "Sending an iMessage and making a FaceTime call must be tested by hand"
unk "Check your serial at checkcoverage.apple.com: it should NOT show a registered Mac"

# ---- Bluetooth -----------------------------------------------------------------
head_ "Bluetooth (Handoff, Instant Hotspot need it)"
bt="$(system_profiler SPBluetoothDataType 2>/dev/null)"
addr="$(awk -F': ' '/^ +Address:/ {print $2; exit}' <<<"$bt")"
state="$(awk -F': ' '/^ +State:/ {print $2; exit}' <<<"$bt")"
if [[ "$addr" =~ ^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$ && ! "$addr" =~ ^(00[:-]){5}00$ ]]; then
    good "Controller has a valid address, state: ${state:-unknown}"
else
    bad "Controller address is '${addr:-none}' (state: ${state:-unknown}); try scripts/reset-bluetooth.sh --check after a reboot"
fi

# ---- Wi-Fi & AWDL --------------------------------------------------------------
head_ "Wi-Fi & AWDL"
wifi="$(system_profiler SPAirPortDataType 2>/dev/null)"
if grep -q "Status: Connected" <<<"$wifi"; then good "Wi-Fi: connected"; else note "Wi-Fi: not connected"; fi
fw="$(awk -F': ' '/Firmware Version/ {print $2; exit}' <<<"$wifi")"
[[ "$fw" == itlwm* ]] && good "Driver: itlwm (Intel). macOS reports up to 802.11ac with this driver" || note "Wi-Fi driver/firmware string: ${fw:-unknown}"
card="$(ioreg -rxc IOPCIDevice 2>/dev/null | python3 -I -c '
import re, sys
for blk in sys.stdin.read().split("+-o ")[1:]:
    m = re.search(r"\"class-code\" = <([0-9a-f]+)>", blk)
    if m and m.group(1).startswith("00800200"):
        g = lambda k: int.from_bytes(bytes.fromhex(re.search(r"\"%s\" = <([0-9a-f]+)>" % k, blk).group(1)[:4]), "little")
        print("%04x:%04x" % (g("vendor-id"), g("device-id")))
        break
' 2>/dev/null || true)"
if [[ "$card" == "8086:2725" ]]; then
    good "Wi-Fi card: Intel AX210 (PCI ${card})"
elif [[ -n "$card" ]]; then
    good "Wi-Fi card PCI ID: ${card}"
fi

if ifconfig awdl0 >/dev/null 2>&1; then
    good "awdl0 present: AirDrop / Universal Control may work"
else
    note "awdl0 is absent: AirDrop, Universal Control, Universal Clipboard, wireless Sidecar and Apple Watch unlock are unsupported with Intel Wi-Fi"
fi

# ---- Continuity & AirPlay --------------------------------------------------------
head_ "Continuity & AirPlay"
net_state="$(netstat -an 2>/dev/null || true)"
if grep -qE '\.7000[[:space:]].*LISTEN' <<<"$net_state"; then good "AirPlay Receiver: listening on port 7000"; else note "AirPlay Receiver is off (System Settings > General > AirDrop & Handoff)"; fi
cam_info="$(system_profiler SPCameraDataType 2>/dev/null || true)"
if grep -qi "iPhone" <<<"$cam_info"; then good "Continuity Camera: an iPhone camera is visible"; else unk "No iPhone camera visible (plug in / unlock the iPhone to test)"; fi
unk "Handoff, Instant Hotspot and Universal Clipboard need a second Apple device to test"

# ---- Graphics ------------------------------------------------------------------
head_ "Graphics & media"
gpu="$(system_profiler SPDisplaysDataType 2>/dev/null)"
if grep -q "Metal Support: Metal" <<<"$gpu"; then good "$(grep -m1 'Chipset Model' <<<"$gpu" | sed 's/^ *//'), $(grep -m1 'Metal Support' <<<"$gpu" | sed 's/^ *//')"; else bad "Metal is not available (iGPU acceleration problem)"; fi

if [[ "$DEEP" == "1" ]]; then
    CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/efi-scripts"
    VT_BIN="${CACHE_DIR}/vt_decode"
    if [[ ! -x "$VT_BIN" ]]; then
        if command -v swiftc >/dev/null 2>&1; then
            mkdir -p "$CACHE_DIR"
            cat > "${CACHE_DIR}/vt_decode.swift" <<'SWIFT'
import VideoToolbox
import CoreMedia
let codecs: [(String, CMVideoCodecType)] = [("H.264", kCMVideoCodecType_H264), ("HEVC", kCMVideoCodecType_HEVC), ("VP9", kCMVideoCodecType_VP9), ("AV1", kCMVideoCodecType_AV1)]
for (n, c) in codecs { print("\(n) \(VTIsHardwareDecodeSupported(c))") }
SWIFT
            swiftc -O "${CACHE_DIR}/vt_decode.swift" -o "$VT_BIN" 2>/dev/null || true
            rm -f "${CACHE_DIR}/vt_decode.swift"
        fi
    fi
    if [[ -x "$VT_BIN" ]]; then
        while read -r codec supported; do
            case "$codec:$supported" in
                H.264:true|HEVC:true) good "Hardware decode: $codec" ;;
                H.264:false|HEVC:false) bad "Hardware decode: $codec is NOT available" ;;
                *:false) note "Hardware decode: $codec not available (software decode; normal for this iGPU)" ;;
                *:true) good "Hardware decode: $codec" ;;
            esac
        done < <("$VT_BIN")
    else
        unk "Video decode test needs swiftc (xcode-select --install)"
    fi
else
    unk "Hardware video decode test skipped (use --deep)"
fi
unk "Netflix / Apple TV+ DRM playback in Safari must be tested by hand"

# ---- Power ---------------------------------------------------------------------
head_ "Sleep & wake"
last_wake="$(pmset -g log 2>/dev/null | grep -E "^[0-9-]+ [0-9:]+ [+-][0-9]{4} +Wake +" | tail -1 | tr -s ' \t' ' ' | cut -c1-110)"
if [[ -n "$last_wake" ]]; then good "Last wake: ${last_wake}"; else unk "No wake events in the power log yet"; fi

echo ""
if [[ "$fail" == "0" ]]; then
    echo -e "${GREEN}No broken prerequisites found.${NC} Items marked ? need a manual test."
else
    echo -e "${RED}Some prerequisites are broken (✗ above).${NC}"
fi
exit "$fail"
