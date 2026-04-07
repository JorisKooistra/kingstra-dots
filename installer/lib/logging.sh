#!/usr/bin/env bash
# =============================================================================
# logging.sh — Kleurrijke log-uitvoer + logbestand
# =============================================================================

LOG_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/kingstra"
LOG_FILE="$LOG_DIR/install.log"

# ANSI kleuren
_RESET='\033[0m'
_BOLD='\033[1m'
_DIM='\033[2m'
_RED='\033[0;31m'
_GREEN='\033[0;32m'
_YELLOW='\033[0;33m'
_BLUE='\033[0;34m'
_MAGENTA='\033[0;35m'
_CYAN='\033[0;36m'
_WHITE='\033[0;37m'

log_init() {
    mkdir -p "$LOG_DIR"
    : > "$LOG_FILE"
    _log_raw "=== kingstra-dots installatie gestart: $(date '+%Y-%m-%d %H:%M:%S') ==="
}

_log_raw() {
    echo "$*" >> "$LOG_FILE"
}

_log_print() {
    local color="$1"
    local prefix="$2"
    shift 2
    local msg="$*"
    local timestamp
    timestamp="$(date '+%H:%M:%S')"
    printf "${color}${_BOLD}[%s]${_RESET} ${color}%s${_RESET} %s\n" "$timestamp" "$prefix" "$msg"
    _log_raw "[$timestamp] $prefix $msg"
}

log_info() {
    _log_print "$_BLUE" "INFO " "$@"
}

log_ok() {
    _log_print "$_GREEN" "OK   " "$@"
}

log_warn() {
    _log_print "$_YELLOW" "WARN " "$@"
}

log_error() {
    _log_print "$_RED" "FOUT " "$@" >&2
}

log_phase() {
    local name="$1"
    echo ""
    printf "${_MAGENTA}${_BOLD}══════════════════════════════════════════════${_RESET}\n"
    printf "${_MAGENTA}${_BOLD}  FASE: %s${_RESET}\n" "$name"
    printf "${_MAGENTA}${_BOLD}══════════════════════════════════════════════${_RESET}\n"
    _log_raw ""
    _log_raw "=== FASE: $name ==="
}

log_step() {
    _log_print "$_CYAN" "  ›  " "$@"
}

log_dry() {
    _log_print "$_DIM" "[DRY]" "$@"
}

print_banner() {
    cat <<'EOF'

   ██╗  ██╗██╗███╗   ██╗ ██████╗ ███████╗████████╗██████╗  █████╗
   ██║ ██╔╝██║████╗  ██║██╔════╝ ██╔════╝╚══██╔══╝██╔══██╗██╔══██╗
   █████╔╝ ██║██╔██╗ ██║██║  ███╗███████╗   ██║   ██████╔╝███████║
   ██╔═██╗ ██║██║╚██╗██║██║   ██║╚════██║   ██║   ██╔══██╗██╔══██║
   ██║  ██╗██║██║ ╚████║╚██████╔╝███████║   ██║   ██║  ██║██║  ██║
   ╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝
              dots — Arch Linux · Hyprland · Quickshell

EOF
}

print_system_info() {
    echo ""
    printf "  ${_BOLD}Distro:${_RESET}     %s\n" "${DETECTED_DISTRO:-onbekend}"
    printf "  ${_BOLD}GPU:${_RESET}        %s\n" "${DETECT_GPU:-onbekend}"
    printf "  ${_BOLD}Laptop:${_RESET}     %s\n" "${DETECT_IS_LAPTOP:-false}"
    printf "  ${_BOLD}Touchpad:${_RESET}   %s\n" "${DETECT_HAS_TOUCHPAD:-false}"
    printf "  ${_BOLD}Fingerprint:${_RESET}%s\n" "${DETECT_HAS_FINGERPRINT:-false}"
    printf "  ${_BOLD}AUR-helper:${_RESET} %s\n" "${AUR_HELPER:-geen}"
    printf "  ${_BOLD}Dry-run:${_RESET}    %s\n" "${DRY_RUN:-false}"
    printf "  ${_BOLD}Back-up:${_RESET}    %s\n" "${BACKUP_DIR:-wordt aangemaakt}"
    printf "  ${_BOLD}Logbestand:${_RESET} %s\n" "$LOG_FILE"
    echo ""
}

print_summary() {
    echo ""
    printf "${_GREEN}${_BOLD}══════════════════════════════════════════════${_RESET}\n"
    printf "${_GREEN}${_BOLD}  Installatie voltooid.${_RESET}\n"
    printf "${_GREEN}${_BOLD}══════════════════════════════════════════════${_RESET}\n"
    printf "  Log: %s\n\n" "$LOG_FILE"
}
