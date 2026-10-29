#!/usr/bin/env bash
# ==============================================================================
# ASUS ROG Strix GL503GE - Sleep/Wake & Power Management Tuning
# ==============================================================================
# Hackintoshes need plain S3 RAM sleep. This applies the pmset values that avoid
# DarkWake loops, and can restore the previous values afterwards.
#
#   setup-sleep.sh            apply (asks first)
#   setup-sleep.sh --revert   restore the values saved before the first apply
#   setup-sleep.sh --status   show current vs. target values
#   --dry-run  print the pmset commands only    --yes  skip the confirmation
# ==============================================================================

set -euo pipefail

# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

STATE_DIR="/Library/Application Support/efi-scripts"
STATE_FILE="${STATE_DIR}/pmset-backup.txt"

# key  target  stock-macOS-default (used by --revert when nothing was saved)
SETTINGS=(
    "hibernatemode 0 3"
    "standby 0 1"
    "autopoweroff 0 1"
    "powernap 0 1"
    "tcpkeepalive 0 1"
    "womp 0 1"
    "proximitywake 0 1"
)

usage() { sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//' | grep -v '^=*$'; }

# Print "<source> <key> <value>" for the keys we manage; source is b (battery) or c (AC).
current_values() {
    pmset -g custom | awk '
        /^Battery Power:/ {src="b"; next}
        /^AC Power:/      {src="c"; next}
        src && NF >= 2    {print src, $1, $2}'
}

value_of() { # src key
    current_values | awk -v s="$1" -v k="$2" '$1==s && $2==k {print $3}'
}

status() {
    printf '%-16s %-8s %-8s %s\n' "setting" "battery" "AC" "target"
    local key target _stock b c
    for entry in "${SETTINGS[@]}"; do
        read -r key target _stock <<<"$entry"
        b=$(value_of b "$key"); c=$(value_of c "$key")
        printf '%-16s %-8s %-8s %s\n' "$key" "${b:--}" "${c:--}" "$target"
    done
    echo ""
    [[ -f "$STATE_FILE" ]] && echo "Backup of previous values: $STATE_FILE" || echo "No backup saved yet."
}

save_backup() {
    [[ -f "$STATE_FILE" ]] && return 0
    run mkdir -p "$STATE_DIR"
    if [[ "${DRY_RUN:-0}" == "1" ]]; then echo "  + save previous values to $STATE_FILE"; return 0; fi
    local key target stock src cur
    : > "$STATE_FILE"
    for entry in "${SETTINGS[@]}"; do
        read -r key target stock <<<"$entry"
        for src in b c; do
            cur=$(value_of "$src" "$key")
            [[ -z "$cur" ]] && continue
            # If it is already at the target, the true "before" is unknown: use the stock default.
            [[ "$cur" == "$target" ]] && cur="$stock"
            echo "$src $key $cur" >> "$STATE_FILE"
        done
    done
}

apply() {
    cat <<EOF
This will set (battery and AC):
  hibernatemode 0, standby 0, autopoweroff 0   no hibernation file: if the battery dies
                                               during sleep, unsaved work is LOST
  powernap 0, tcpkeepalive 0, womp 0           no network wakeups while asleep: Find My,
                                               Mail push and Wake-on-LAN stop working asleep
  proximitywake 0                              no wake from nearby devices
Undo any time with: $0 --revert
EOF
    [[ "${DRY_RUN:-0}" == "1" ]] || confirm "Continue?" || { echo "Aborted."; exit 0; }

    save_backup
    local key target _stock
    for entry in "${SETTINGS[@]}"; do
        read -r key target _stock <<<"$entry"
        # Some keys do not exist on every Mac; skip those quietly.
        if [[ -z "$(value_of b "$key")$(value_of c "$key")" ]]; then
            echo "  - $key not supported here, skipped"
            continue
        fi
        run pmset -a "$key" "$target"
    done
    remove_sleepimage
    ok "Power settings applied."
}

remove_sleepimage() {
    [[ -f /var/vm/sleepimage ]] || return 0
    info "Replacing /var/vm/sleepimage with an empty locked file..."
    if [[ "${DRY_RUN:-0}" == "1" ]]; then echo "  + rm/touch/chflags uchg /var/vm/sleepimage"; return 0; fi
    if ! { rm -f /var/vm/sleepimage && touch /var/vm/sleepimage && chflags uchg /var/vm/sleepimage; } 2>/dev/null; then
        warn "Could not replace sleepimage (protected); harmless with hibernatemode 0."
    fi
}

revert() {
    if [[ -f /var/vm/sleepimage ]]; then
        chflags nouchg /var/vm/sleepimage 2>/dev/null || true
    fi
    if [[ -f "$STATE_FILE" ]]; then
        info "Restoring values saved in $STATE_FILE"
        local src key val flag
        while read -r src key val; do
            flag="-b"; [[ "$src" == "c" ]] && flag="-c"
            run pmset "$flag" "$key" "$val"
        done < "$STATE_FILE"
        [[ "${DRY_RUN:-0}" == "1" ]] || rm -f "$STATE_FILE"
    else
        warn "No saved values found; restoring stock macOS defaults."
        local key _t stock
        for entry in "${SETTINGS[@]}"; do
            read -r key _t stock <<<"$entry"
            [[ -z "$(value_of b "$key")$(value_of c "$key")" ]] || run pmset -a "$key" "$stock"
        done
    fi
    ok "Power settings reverted."
}

MODE="apply"
for arg in "$@"; do
    case "$arg" in
        --revert)  MODE="revert" ;;
        --status)  MODE="status" ;;
        --dry-run) DRY_RUN=1 ;;
        --yes|-y)  ASSUME_YES=1 ;;
        -h|--help) usage; exit 0 ;;
        *) usage; die "Unknown option: $arg" ;;
    esac
done

if [[ "$MODE" != "status" && "${DRY_RUN:-0}" != "1" ]]; then
    ensure_root "$0" "$@"
fi

case "$MODE" in
    status) status ;;
    apply)  apply ;;
    revert) revert ;;
esac
