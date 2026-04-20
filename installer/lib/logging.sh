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
INSTALL_KERNEL_PRINTK_OLD=""

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
    if [[ "$INSTALL_UI_MODE" == "true" ]]; then
        trap '_install_log_cleanup' EXIT
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

_tput_safe() {
    command -v tput >/dev/null 2>&1 || return 0
    tput "$@" 2>/dev/null || return 0
}

_ui_banner_rows() {
    echo 11
}

_ui_restore_scroll_region() {
    local term_rows
    term_rows="$(_tput_safe lines)"
    [[ -n "$term_rows" ]] || term_rows=24
    _tput_safe csr 0 "$((term_rows - 1))"
}

_restore_kernel_console_loglevel() {
    [[ -n "${INSTALL_KERNEL_PRINTK_OLD:-}" ]] || return 0
    command -v sudo >/dev/null 2>&1 || return 0
    sudo -n true >/dev/null 2>&1 || return 0
    sudo sysctl -q -w "kernel.printk=$INSTALL_KERNEL_PRINTK_OLD" >/dev/null 2>&1 || true
    INSTALL_KERNEL_PRINTK_OLD=""
}

_install_log_cleanup() {
    _restore_kernel_console_loglevel
    _ui_restore_scroll_region
}

suppress_kernel_console_messages() {
    [[ "${INSTALL_UI_MODE:-false}" == "true" ]] || return 0
    [[ "${INSTALL_SUPPRESS_KERNEL_MESSAGES:-true}" == "true" ]] || return 0
    [[ -r /proc/sys/kernel/printk ]] || return 0
    command -v sudo >/dev/null 2>&1 || return 0
    sudo -n true >/dev/null 2>&1 || return 0

    local current default minimum boot
    read -r current default minimum boot < /proc/sys/kernel/printk || return 0
    [[ "$current" =~ ^[0-9]+$ ]] || return 0

    INSTALL_KERNEL_PRINTK_OLD="$current $default $minimum $boot"
    export INSTALL_KERNEL_PRINTK_OLD

    if (( current > 3 )); then
        sudo sysctl -q -w "kernel.printk=3 $default $minimum $boot" >/dev/null 2>&1 || true
        _log_raw "Kernel console loglevel tijdelijk verlaagd: $INSTALL_KERNEL_PRINTK_OLD -> 3 $default $minimum $boot"
    fi
}

_ui_enable_scroll_region() {
    local banner_rows term_rows
    banner_rows="$(_ui_banner_rows)"
    term_rows="$(_tput_safe lines)"
    [[ -n "$term_rows" ]] || term_rows=24
    _tput_safe csr "$banner_rows" "$((term_rows - 1))"
    _tput_safe cup "$banner_rows" 0
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

_render_detect_summary() {
    printf "GPU:%s Laptop:%s Touch:%s Tablet:%s Finger:%s" \
        "${DETECT_GPU:-?}" \
        "${DETECT_IS_LAPTOP:-false}" \
        "${DETECT_HAS_TOUCHSCREEN:-false}" \
        "${ENABLE_TABLET_MODE:-false}" \
        "${DETECT_HAS_FINGERPRINT:-false}"
}

_progress_line_columns() {
    local cols
    cols="$(_tput_safe cols)"
    [[ "$cols" =~ ^[0-9]+$ ]] || cols="${COLUMNS:-80}"
    [[ "$cols" =~ ^[0-9]+$ ]] || cols=80
    (( cols >= 20 )) || cols=20
    echo "$cols"
}

_progress_line_message() {
    local prefix="$1"
    local msg="$2"
    local cols max
    cols="$(_progress_line_columns)"

    # Leave one column free so terminals do not auto-wrap the spinner row.
    max=$((cols - ${#prefix} - 1))
    (( max >= 10 )) || max=10

    if (( ${#msg} > max )); then
        printf "%s..." "${msg:0:$((max - 3))}"
    else
        printf "%s" "$msg"
    fi
}

_progress_line_print() {
    local marker="$1"
    local msg="$2"
    local prefix="  [$marker] "
    printf "\r\033[K%s%s" "$prefix" "$(_progress_line_message "$prefix" "$msg")"
}

log_phase() {
    local name="$1"
    local current="${2:-$INSTALL_CURRENT_PHASE}"
    local total="${3:-$INSTALL_TOTAL_PHASES}"

    if [[ "$INSTALL_UI_MODE" == "true" ]]; then
        _ui_restore_scroll_region
        _ui_clear
        print_banner
        _ui_enable_scroll_region
        if (( total > 0 )); then
            printf "  ${_BOLD}Fase:${_RESET} %s (%d/%d)\n" "$name" "$current" "$total"
            printf "  ${_BOLD}Voortgang:${_RESET} %s\n\n" "$(_render_progress_bar "$total" "$current")"
        else
            printf "  ${_BOLD}Fase:${_RESET} %s\n\n" "$name"
        fi
        printf "  ${_BOLD}Detectie:${_RESET} %s\n\n" "$(_render_detect_summary)"
    else
        echo ""
        printf "${_MAGENTA}${_BOLD}══════════════════════════════════════════════${_RESET}\n"
        printf "${_MAGENTA}${_BOLD}  FASE: %s${_RESET}\n" "$name"
        printf "${_MAGENTA}${_BOLD}══════════════════════════════════════════════${_RESET}\n"
        printf "  Detectie: %s\n" "$(_render_detect_summary)"
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
    _progress_line_print ".." "$msg"
}

_progress_task_tick() {
    local spinner="${1:-.}"
    local msg="${2:-$INSTALL_LAST_TASK_MSG}"
    if [[ "$INSTALL_UI_MODE" != "true" || "${INSTALL_VERBOSE_COMMANDS:-false}" == "true" ]]; then
        return 0
    fi
    _progress_line_print "$spinner" "$msg"
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
        _progress_line_print "OK" "$msg"
        printf "\n"
        _log_raw "TASK OK: $msg"
    else
        _progress_line_print "!!" "$msg"
        printf "\n"
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
    printf "  ${_BOLD}Touchscreen:${_RESET}%s\n" "${DETECT_HAS_TOUCHSCREEN:-false}"
    printf "  ${_BOLD}Tablet mode:${_RESET}%s\n" "${ENABLE_TABLET_MODE:-false}"
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
