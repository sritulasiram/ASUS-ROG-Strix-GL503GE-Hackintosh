#!/usr/bin/env bash
# ==============================================================================
# ASUS ROG Strix GL503GE - Real-Time Hardware Thermal Telemetry
# ==============================================================================
# Samples live AppleSMC hardware sensors (Package TC0P, Die TC0D, and Cores TC1C-TC6C)
# to provide accurate thermal metrics on macOS Tahoe (Darwin 25/26).
# ==============================================================================

set -euo pipefail

BOLD="\033[1m"
CYAN="\033[0;36m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
RESET="\033[0m"

WORK_DIR="$(mktemp -d)"
TMP_BIN="${WORK_DIR}/read_smc"

cleanup() {
    rm -rf "${WORK_DIR}" 2>/dev/null || true
}
trap cleanup EXIT

cat << 'EOF' > "${TMP_BIN}.c"
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
EOF

if ! clang -O2 -framework IOKit "${TMP_BIN}.c" -o "${TMP_BIN}"; then
    echo "Error: clang failed. Install the Xcode Command Line Tools: xcode-select --install" >&2
    exit 1
fi

echo -e "${BOLD}${CYAN}==================================================================${RESET}"
echo -e "${BOLD}${CYAN}   ASUS ROG Strix GL503GE - Hardware Thermal Monitor               ${RESET}"
echo -e "${BOLD}${CYAN}==================================================================${RESET}\n"

readings=$("${TMP_BIN}") || { echo "Error: could not open AppleSMC (is VirtualSMC loaded?)" >&2; exit 1; }
pkg_temp=$(echo "$readings" | awk -F'|' '{print $1}' | cut -d: -f2)
if (( $(echo "$pkg_temp <= 0" | bc -l) )); then
    echo "Error: TC0P (CPU package) sensor unreadable; is SMCProcessor.kext loaded?" >&2
    exit 1
fi

color="${GREEN}"
status="OPTIMAL / COOL"
if (( $(echo "$pkg_temp >= 65" | bc -l) )); then
    color="${YELLOW}"
    status="NORMAL ACTIVITY"
fi
if (( $(echo "$pkg_temp >= 80" | bc -l) )); then
    color="${RED}"
    status="HIGH THERMAL LOAD"
fi

echo -e "  ${BOLD}CPU Package Die:${RESET}    ${color}${pkg_temp} °C${RESET}  (${status})"
echo -e "  ${BOLD}Core Temperatures:${RESET}"
echo "$readings" | tr '|' '\n' | grep '^C' | while read -r line; do
    c_name=$(echo "$line" | cut -d: -f1)
    c_val=$(echo "$line" | cut -d: -f2)
    echo -e "    - Core ${c_name#C}: ${c_val} °C"
done

echo -e "\n${BOLD}${CYAN}------------------------------------------------------------------${RESET}"
echo -e "${BOLD}Hardware Fan Modes (Controlled via ACPI hotkey Fn + F5):${RESET}"
echo -e "  ${GREEN}1. Normal / Balanced (0x00):${RESET} Factory automatic EC thermal curve"
echo -e "  ${YELLOW}2. Overboost Turbo (0x01):${RESET}  Dual blowers forced to ~5,000+ RPM (Max Cooling)"
echo -e "  ${CYAN}3. Silent Quiet (0x02):${RESET}     Low-RPM acoustic-prioritized profile"
echo -e "${BOLD}${CYAN}==================================================================${RESET}\n"

