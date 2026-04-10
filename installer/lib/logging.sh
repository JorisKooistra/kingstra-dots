#!/usr/bin/env bash
# =============================================================================
# logging.sh — Kleurrijke log-uitvoer + logbestand
# =============================================================================

LOG_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/kingstra"
LOG_FILE="$LOG_DIR/install.log"
INSTALL_UI_MODE=false
INSTALL_TOTAL_PHASES=0
INSTALL_CURRENT_PHASE=0
INSTALL_LAST_TASK_MSG=""

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
    if [[ -t 1 && "${TERM:-}" != "dumb" ]]; then
        INSTALL_UI_MODE=true
    else
        INSTALL_UI_MODE=false
    fi
    export INSTALL_UI_MODE
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

set_phase_progress() {
    INSTALL_TOTAL_PHASES="${1:-0}"
    INSTALL_CURRENT_PHASE="${2:-0}"
    export INSTALL_TOTAL_PHASES INSTALL_CURRENT_PHASE
}

_ui_clear() {
    if [[ "$INSTALL_UI_MODE" == "true" ]]; then
        printf '\033c'
    fi
}

_render_progress_bar() {
    local total="${1:-0}"
    local current="${2:-0}"
    local width=30
    local filled=0
    local percent=0

    if (( total > 0 )); then
        filled=$(( current * width / total ))
        percent=$(( current * 100 / total ))
    fi

    local bar=""
    local i
    for (( i=0; i<width; i++ )); do
        if (( i < filled )); then
            bar+="#"
        else
            bar+="-"
        fi
    done
    printf "[%s] %3d%%" "$bar" "$percent"
}

log_phase() {
    local name="$1"
    local current="${2:-$INSTALL_CURRENT_PHASE}"
    local total="${3:-$INSTALL_TOTAL_PHASES}"

    if [[ "$INSTALL_UI_MODE" == "true" ]]; then
        _ui_clear
        print_banner
        if (( total > 0 )); then
            printf "  ${_BOLD}Fase:${_RESET} %s (%d/%d)\n" "$name" "$current" "$total"
            printf "  ${_BOLD}Voortgang:${_RESET} %s\n\n" "$(_render_progress_bar "$total" "$current")"
        else
            printf "  ${_BOLD}Fase:${_RESET} %s\n\n" "$name"
        fi
    else
        echo ""
        printf "${_MAGENTA}${_BOLD}══════════════════════════════════════════════${_RESET}\n"
        printf "${_MAGENTA}${_BOLD}  FASE: %s${_RESET}\n" "$name"
        printf "${_MAGENTA}${_BOLD}══════════════════════════════════════════════${_RESET}\n"
    fi

    _log_raw ""
    _log_raw "=== FASE: $name (${current}/${total}) ==="
}

log_step() {
    _log_print "$_CYAN" "  ›  " "$@"
}

log_dry() {
    _log_print "$_DIM" "[DRY]" "$@"
}

_progress_task_start() {
    local msg="${1:-bezig}"
    INSTALL_LAST_TASK_MSG="$msg"
    _log_raw "TASK START: $msg"
    if [[ "$INSTALL_UI_MODE" != "true" || "${INSTALL_VERBOSE_COMMANDS:-false}" == "true" ]]; then
        log_step "$msg"
        return 0
    fi
    printf "  [..] %s" "$msg"
}

_progress_task_tick() {
    local spinner="${1:-.}"
    local msg="${2:-$INSTALL_LAST_TASK_MSG}"
    if [[ "$INSTALL_UI_MODE" != "true" || "${INSTALL_VERBOSE_COMMANDS:-false}" == "true" ]]; then
        return 0
    fi
    printf "\r  [%s] %s" "$spinner" "$msg"
}

_progress_task_end() {
    local rc="${1:-0}"
    local msg="${2:-$INSTALL_LAST_TASK_MSG}"
    if [[ "$INSTALL_UI_MODE" != "true" || "${INSTALL_VERBOSE_COMMANDS:-false}" == "true" ]]; then
        if [[ "$rc" -eq 0 ]]; then
            log_ok "$msg"
        else
            log_error "$msg"
        fi
        return 0
    fi

    if [[ "$rc" -eq 0 ]]; then
        printf "\r  [OK] %s\n" "$msg"
        _log_raw "TASK OK: $msg"
    else
        printf "\r  [!!] %s\n" "$msg"
        _log_raw "TASK FAIL($rc): $msg"
    fi
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
