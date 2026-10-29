# shellcheck shell=bash
# ==============================================================================
# Shared helpers for the scripts in this folder. Source it, do not execute it:
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"
# ==============================================================================

# Colours only when writing to a terminal, so piped/logged output stays clean.
if [[ -t 1 ]]; then
    BOLD=$'\033[1m'; RED=$'\033[0;31m'; GREEN=$'\033[0;32m'
    BLUE=$'\033[0;34m'; YELLOW=$'\033[1;33m'; CYAN=$'\033[0;36m'; NC=$'\033[0m'
else
    BOLD=""; RED=""; GREEN=""; BLUE=""; YELLOW=""; CYAN=""; NC=""
fi
RESET="${NC}"

info() { echo -e "${BLUE}[*]${NC} $*"; }
ok()   { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*" >&2; }
die()  { echo -e "${RED}[✗]${NC} $*" >&2; exit 1; }

# Re-run the calling script through sudo unless already root.
# Usage: ensure_root "$0" "$@"
ensure_root() {
    [[ $EUID -eq 0 ]] || exec sudo "$@"
}

# Ask a yes/no question; ASSUME_YES=1 answers yes. Default is no.
confirm() {
    [[ "${ASSUME_YES:-0}" == "1" ]] && return 0
    local ans
    read -r -p "$1 [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

# Home directory of the person who invoked sudo (or the current user).
real_home() {
    local user="${SUDO_USER:-$USER}"
    dscl . -read "/Users/${user}" NFSHomeDirectory 2>/dev/null | awk '{print $2}'
}

# Run a command, or only print it when DRY_RUN=1.
run() {
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
        echo "  + $*"
    else
        "$@"
    fi
}
