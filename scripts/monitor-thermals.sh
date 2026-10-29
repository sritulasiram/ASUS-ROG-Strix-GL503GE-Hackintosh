#!/usr/bin/env bash
# ==============================================================================
# ASUS ROG Strix GL503GE - CPU Thermal Telemetry (AppleSMC via VirtualSMC)
# ==============================================================================
# Reads the CPU package (TC0P) and per-core (TC1C-TC6C) temperatures.
#
#   monitor-thermals.sh               print once
#   monitor-thermals.sh --watch [N]   refresh every N seconds (default 2), Ctrl-C to stop
#   WARN_C=70 CRIT_C=85 monitor-thermals.sh   change the colour thresholds (default 65 / 80)
#
# The small C reader is compiled on first use and cached in
# ${XDG_CACHE_HOME:-~/.cache}/efi-scripts (needs the Xcode Command Line Tools once).
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

WARN_C="${WARN_C:-65}"
CRIT_C="${CRIT_C:-80}"
WATCH=0
INTERVAL=2

usage() { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//' | grep -v '^=*$'; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --watch) WATCH=1; if [[ "${2:-}" =~ ^[0-9]+$ ]]; then INTERVAL="$2"; shift; fi ;;
        -h|--help) usage; exit 0 ;;
        *) usage; die "Unknown option: $1" ;;
    esac
    shift
done

read -r -d '' C_SOURCE <<'CSRC' || true
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <mach/mach.h>
#include <IOKit/IOKitLib.h>

typedef struct { uint8_t a, b, c, d; uint16_t e; } SMCVersion;
typedef struct { uint16_t a, b; uint32_t c, d, e; } SMCPLimitData;
typedef struct { uint32_t a, b; uint8_t c; } SMCKeyInfoData;
typedef struct {
    uint32_t key;
    SMCVersion vers;
    SMCPLimitData pLimit;
    SMCKeyInfoData info;
    uint8_t res, stat, data8;
    uint32_t data32;
    uint8_t bytes[32];
} SMCKeyData;

static inline uint32_t str_to_key(const char *s) {
    return ((uint32_t)s[0] << 24) | ((uint32_t)s[1] << 16) | ((uint32_t)s[2] << 8) | (uint32_t)s[3];
}

io_connect_t conn = 0;

int read_key(const char *key_str, SMCKeyData *out) {
    SMCKeyData in;
    size_t in_size = sizeof(SMCKeyData), out_size = sizeof(SMCKeyData);
    memset(&in, 0, sizeof(in));
    in.key = str_to_key(key_str);
    in.data8 = 5;
    in.info.a = 2;
    if (IOConnectCallStructMethod(conn, 2, &in, in_size, out, &out_size) != KERN_SUCCESS) return 0;
    return (out->res == 0);
}

int main(int argc, char **argv) {
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (!service || IOServiceOpen(service, mach_task_self(), 0, &conn) != KERN_SUCCESS) return 1;

    SMCKeyData data;
    double pkg = 0;
    if (read_key("TC0P", &data)) {
        int16_t raw = ((int16_t)data.bytes[0] << 8) | data.bytes[1];
        pkg = (double)raw / 256.0;
    }

    if (argc > 1 && strcmp(argv[1], "--raw") == 0) {
        printf("%.1f\n", pkg);
        IOServiceClose(conn);
        return 0;
    }

    printf("PKG:%.1f", pkg);
    const char *cores[] = {"TC1C", "TC2C", "TC3C", "TC4C", "TC5C", "TC6C"};
    for (int i = 0; i < 6; i++) {
        if (read_key(cores[i], &data)) {
            int16_t raw = ((int16_t)data.bytes[0] << 8) | data.bytes[1];
            printf("|C%d:%.1f", i + 1, (double)raw / 256.0);
        }
    }
    printf("\n");

    IOServiceClose(conn);
    return 0;
}
CSRC

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/efi-scripts"
SRC_HASH="$(printf '%s' "$C_SOURCE" | shasum | cut -c1-12)"
SMC_BIN="${CACHE_DIR}/read_smc-${SRC_HASH}"

if [[ ! -x "$SMC_BIN" ]]; then
    mkdir -p "$CACHE_DIR"
    TMP_SRC="${CACHE_DIR}/read_smc-${SRC_HASH}.c"
    printf '%s\n' "$C_SOURCE" > "$TMP_SRC"
    if ! clang -O2 -framework IOKit "$TMP_SRC" -o "$SMC_BIN"; then
        rm -f "$TMP_SRC"
        die "clang failed. Install the Xcode Command Line Tools: xcode-select --install"
    fi
    rm -f "$TMP_SRC"
    # Drop binaries built from older versions of the source
    find "$CACHE_DIR" -name 'read_smc-*' ! -name "read_smc-${SRC_HASH}" -delete 2>/dev/null || true
fi

render() {
    local readings pkg_temp color status
    readings="$("$SMC_BIN")" || die "Could not open AppleSMC (is VirtualSMC loaded?)"
    pkg_temp="$(cut -d'|' -f1 <<<"$readings" | cut -d: -f2)"
    if awk -v t="$pkg_temp" 'BEGIN {exit !(t <= 0)}'; then
        die "TC0P (CPU package) sensor unreadable; is SMCProcessor.kext loaded?"
    fi

    color="${GREEN}"; status="OPTIMAL / COOL"
    if awk -v t="$pkg_temp" -v w="$WARN_C" 'BEGIN {exit !(t >= w)}'; then color="${YELLOW}"; status="NORMAL ACTIVITY"; fi
    if awk -v t="$pkg_temp" -v c="$CRIT_C" 'BEGIN {exit !(t >= c)}'; then color="${RED}"; status="HIGH THERMAL LOAD"; fi

    echo -e "${BOLD}${CYAN}==================================================================${RESET}"
    echo -e "${BOLD}${CYAN}   ASUS ROG Strix GL503GE - CPU Thermal Monitor                    ${RESET}"
    echo -e "${BOLD}${CYAN}==================================================================${RESET}"
    echo -e "  ${BOLD}CPU Package:${RESET}  ${color}${pkg_temp} °C${RESET}  (${status})"
    echo -e "  ${BOLD}Cores:${RESET}"
    tr '|' '\n' <<<"$readings" | { grep '^C' || true; } | while IFS=: read -r name val; do
        echo "    - Core ${name#C}: ${val} °C"
    done
    echo -e "${BOLD}${CYAN}------------------------------------------------------------------${RESET}"
    echo "  Fan profile: Fn + F5 cycles Normal / Overboost / Silent (SSDT-FAN.aml)."
    echo "  Thresholds: warn >= ${WARN_C} °C, high >= ${CRIT_C} °C."
}

if [[ "$WATCH" == "1" ]]; then
    trap 'echo; exit 0' INT TERM
    while true; do
        clear 2>/dev/null || printf '\033c'
        render
        sleep "$INTERVAL"
    done
else
    render
fi
