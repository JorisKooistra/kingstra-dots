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

# Compacte weergave: in een terminal tonen we per fase één regel plus een
# live voortgangsregel onderaan. Alles staat volledig in het logbestand;
# waarschuwingen en fouten blijven altijd zichtbaar.
INSTALL_UI_QUIET=false
UI_LIVE_SHOWN=false
UI_SPIN_IDX=0
UI_PHASES_DONE=0
UI_PHASE_ID=""
UI_PHASE_NUM=""
UI_PHASE_TITLE=""
UI_PHASE_START=0
UI_PHASE_WARNS=0
UI_PHASE_ERRS=0
UI_PHASE_PKGS=0
UI_PHASE_DRY=0
UI_PHASE_HEADER_SHOWN=false
UI_TOTAL_WARNS=0
UI_TOTAL_ERRS=0
UI_TOTAL_PKGS=0
UI_TOTAL_DRY=0
UI_GLYPH_OK="OK"
UI_GLYPH_WARN="!"
UI_GLYPH_FAIL="X"
UI_GLYPH_STEP=">"
UI_GLYPH_DOT="-"
UI_BAR_FULL="#"
UI_BAR_EMPTY="-"
UI_SPIN=('-' '\\' '|' '/')
# Vaste kop bovenaan (banner + voortgang); de rest scrollt eronder.
UI_HEADER=false
UI_HEADER_ROWS=0
UI_PROGRESS_ROW=0

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
    if [[ "$INSTALL_UI_MODE" == "true" && "${INSTALL_VERBOSE_COMMANDS:-false}" != "true" ]]; then
        INSTALL_UI_QUIET=true
    fi
    _ui_init_glyphs
    # fd 3/4 wijzen altijd naar de terminal. In de compacte weergave gaat de
    # uitvoer van de fases zelf naar het log; de UI schrijft via fd 3/4.
    exec 3>&1 4>&2
    export INSTALL_UI_MODE INSTALL_UI_QUIET
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
    if [[ "$INSTALL_UI_QUIET" == "true" ]]; then
        _log_raw "[$timestamp] $prefix $msg"
        case "$prefix" in
            "WARN ")
                UI_PHASE_WARNS=$((UI_PHASE_WARNS + 1))
                _ui_persist "$_YELLOW" "$UI_GLYPH_WARN" "$msg"
                ;;
            "FOUT ")
                UI_PHASE_ERRS=$((UI_PHASE_ERRS + 1))
                _ui_persist "$_RED" "$UI_GLYPH_FAIL" "$msg"
                ;;
            "[DRY]")
                # Dry-run acties staan in het log; --verbose toont ze hier.
                UI_PHASE_DRY=$((UI_PHASE_DRY + 1))
                INSTALL_LAST_TASK_MSG="$msg"
                _ui_live_draw "$msg"
                ;;
            *)
                INSTALL_LAST_TASK_MSG="$msg"
                UI_SPIN_IDX=$((UI_SPIN_IDX + 1))
                _ui_live_draw "$msg"
                ;;
        esac
        return 0
    fi
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

# Belangrijke mededeling die ook in de compacte weergave zichtbaar blijft.
log_note() {
    if [[ "$INSTALL_UI_QUIET" == "true" ]]; then
        _log_raw "[$(date '+%H:%M:%S')] NOTE  $*"
        _ui_persist "$_BLUE" "$UI_GLYPH_DOT" "$*"
        return 0
    fi
    log_info "$@"
}

# Witregel, behalve in de compacte weergave.
log_blank() {
    [[ "$INSTALL_UI_QUIET" == "true" ]] && return 0
    echo ""
}

# Telt geïnstalleerde pakketten mee voor de fase-samenvatting.
ui_count_packages() {
    local n="${1:-0}"
    [[ "$n" =~ ^[0-9]+$ ]] || return 0
    UI_PHASE_PKGS=$((UI_PHASE_PKGS + n))
}

# ---------------------------------------------------------------------------
# Compacte weergave: live voortgangsregel + één regel per fase
# ---------------------------------------------------------------------------
_ui_init_glyphs() {
    local charmap=""
    charmap="$(locale charmap 2>/dev/null || true)"
    if [[ "$charmap" == "UTF-8" || "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" =~ [Uu][Tt][Ff]-?8 ]]; then
        UI_GLYPH_OK="✓"
        UI_GLYPH_WARN="!"
        UI_GLYPH_FAIL="✗"
        UI_GLYPH_STEP="›"
        UI_GLYPH_DOT="·"
        UI_BAR_FULL="█"
        UI_BAR_EMPTY="░"
        UI_SPIN=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    fi
}

# Leesbare naam per fase; onbekende fases tonen hun bestandsnaam.
_ui_phase_title() {
    case "$1" in
        01_project_base) echo "Projectbasis" ;;
        02_shell_terminal) echo "Shell en terminal" ;;
        03_hypr_core) echo "Hyprland" ;;
        04_bindings) echo "Sneltoetsen" ;;
        05_ui_quickshell) echo "Quickshell" ;;
        06_notifications) echo "Meldingen" ;;
        07_launcher) echo "Launcher" ;;
        08_theming) echo "Thema en kleuren" ;;
        09_wallpaper) echo "Achtergronden" ;;
        10_session) echo "Sessie en login" ;;
        11_apps_tools) echo "Apps en tools" ;;
        12_network_resume_fixes) echo "Netwerk en slaapstand" ;;
        13_monitoring) echo "Monitoring" ;;
        14_profiles) echo "Hardwareprofiel" ;;
        15_finalize) echo "Afronden" ;;
        *) echo "$1" ;;
    esac
}

_ui_duration() {
    local s="${1:-0}"
    if (( s >= 60 )); then
        printf '%dm%02ds' "$((s / 60))" "$((s % 60))"
    else
        printf '%ds' "$s"
    fi
}

_ui_plural() {
    local n="$1" one="$2" many="$3"
    if (( n == 1 )); then
        printf '%d %s' "$n" "$one"
    else
        printf '%d %s' "$n" "$many"
    fi
}

_ui_bar() {
    local total="${1:-0}" current="${2:-0}" width="${3:-24}"
    local filled=0 i bar=""
    (( total > 0 )) && filled=$((current * width / total))
    (( filled > width )) && filled=$width
    for (( i = 0; i < width; i++ )); do
        if (( i < filled )); then bar+="$UI_BAR_FULL"; else bar+="$UI_BAR_EMPTY"; fi
    done
    printf '%s' "$bar"
}

# Tekent de voortgangsregel opnieuw op de huidige regel (zonder newline).
_ui_live_draw() {
    [[ "$INSTALL_UI_QUIET" == "true" ]] || return 0
    local msg="${1:-$INSTALL_LAST_TASK_MSG}"
    local total="${INSTALL_TOTAL_PHASES:-0}"
    local spin="${UI_SPIN[UI_SPIN_IDX % ${#UI_SPIN[@]}]}"
    local plain colored percent=0 bar
    (( total > 0 && UI_PHASES_DONE >= total )) && spin="$UI_GLYPH_OK"

    if (( total > 0 )); then
        percent=$((UI_PHASES_DONE * 100 / total))
        bar="$(_ui_bar "$total" "$UI_PHASES_DONE")"
        plain="  $spin $bar $(printf '%3d%%' "$percent")  "
        colored="  ${_CYAN}${spin}${_RESET} ${_GREEN}${bar}${_RESET} ${_BOLD}$(printf '%3d%%' "$percent")${_RESET}  "
        if [[ -n "$UI_PHASE_TITLE" ]]; then
            plain+="$UI_PHASE_TITLE $UI_GLYPH_STEP "
            colored+="${_BOLD}${UI_PHASE_TITLE}${_RESET} ${_DIM}${UI_GLYPH_STEP}${_RESET} "
        fi
    else
        plain="  $spin "
        colored="  ${_CYAN}${spin}${_RESET} "
    fi

    if [[ "$UI_HEADER" == "true" ]]; then
        # Opslaan, naar de voortgangsregel in de kop, terug naar de scrollregio.
        printf '\0337\033[%d;1H\033[2K%b%b%s%b\0338' "$UI_PROGRESS_ROW" \
            "$colored" "$_DIM" "$(_progress_line_message "$plain" "$msg")" "$_RESET" >&3
        return 0
    fi
    printf '\033[?25l\r\033[K%b%b%s%b' "$colored" "$_DIM" "$(_progress_line_message "$plain" "$msg")" "$_RESET" >&3
    UI_LIVE_SHOWN=true
}

# Zet de banner en voortgangsregel vast bovenaan via een scrollregio.
# Te kleine terminals houden de voortgangsregel onderaan.
_ui_header_setup() {
    [[ "$INSTALL_UI_QUIET" == "true" && "${KINGSTRA_UI_EMBEDDED:-false}" != "true" ]] || return 1
    [[ "${INSTALL_FIXED_HEADER:-true}" == "true" ]] || return 1
    local rows
    rows="$(_ui_term_size rows)"
    [[ "$rows" =~ ^[0-9]+$ ]] || return 1

    if (( rows >= 32 )); then
        printf '\033[H\033[2J\033[3J' >&3
        _print_banner_art >&3
        UI_PROGRESS_ROW=10
    elif (( rows >= 14 )); then
        printf '\033[H\033[2J\033[3J' >&3
        printf "\n  ${_BOLD}KINGSTRA${_RESET} ${_DIM}dots %s Arch Linux %s Hyprland %s Quickshell${_RESET}\n" \
            "$UI_GLYPH_DOT" "$UI_GLYPH_DOT" "$UI_GLYPH_DOT" >&3
        UI_PROGRESS_ROW=4
    else
        return 1
    fi
    UI_HEADER_ROWS=$((UI_PROGRESS_ROW + 1))
    UI_HEADER=true
    printf '\033[%d;%dr\033[%d;1H' "$((UI_HEADER_ROWS + 1))" "$rows" "$((UI_HEADER_ROWS + 1))" >&3
    _ui_live_draw "voorbereiden..."
    return 0
}

# Heft de scrollregio op; de cursor blijft waar hij was.
_ui_header_teardown() {
    [[ "$UI_HEADER" == "true" ]] || return 0
    UI_HEADER=false
    printf '\0337\033[r\0338\033[?25h' >&3
}

# Haalt de voortgangsregel weg en geeft de cursor terug, zodat een vraag of
# interactief commando een schone regel heeft.
ui_release_terminal() {
    [[ "$INSTALL_UI_QUIET" == "true" ]] || return 0
    if [[ "$UI_LIVE_SHOWN" == "true" ]]; then
        printf '\r\033[K' >&3
        UI_LIVE_SHOWN=false
    fi
    printf '\033[?25h' >&3
}

_ui_phase_header() {
    [[ -n "$UI_PHASE_ID" && "$UI_PHASE_HEADER_SHOWN" != "true" ]] || return 0
    printf "  ${_CYAN}%s${_RESET} %s  ${_BOLD}%s${_RESET}\n" "$UI_GLYPH_STEP" "$UI_PHASE_NUM" "$UI_PHASE_TITLE" >&3
    UI_PHASE_HEADER_SHOWN=true
}

# Blijvende regel (waarschuwing, fout, notitie) boven de voortgangsregel.
_ui_persist() {
    local color="$1" glyph="$2" msg="$3"
    ui_release_terminal
    _ui_phase_header
    printf "     ${color}%s${_RESET} %s\n" "$glyph" "$msg" >&3
    [[ -n "$UI_PHASE_ID" ]] && _ui_live_draw
    return 0
}

# Sluit de lopende fase af met één samenvattingsregel.
_ui_phase_finish() {
    [[ "$INSTALL_UI_QUIET" == "true" && -n "$UI_PHASE_ID" ]] || return 0
    local elapsed=$((SECONDS - UI_PHASE_START))
    local glyph="$UI_GLYPH_OK" color="$_GREEN" details=""

    if (( UI_PHASE_ERRS > 0 )); then
        glyph="$UI_GLYPH_FAIL"; color="$_RED"
    elif (( UI_PHASE_WARNS > 0 )); then
        glyph="$UI_GLYPH_WARN"; color="$_YELLOW"
    fi
    (( UI_PHASE_PKGS > 0 )) && details+="$(_ui_plural "$UI_PHASE_PKGS" "pakket" "pakketten") $UI_GLYPH_DOT "
    (( UI_PHASE_DRY > 0 )) && details+="$(_ui_plural "$UI_PHASE_DRY" "actie" "acties") (dry-run) $UI_GLYPH_DOT "
    (( UI_PHASE_WARNS > 0 )) && details+="$(_ui_plural "$UI_PHASE_WARNS" "waarschuwing" "waarschuwingen") $UI_GLYPH_DOT "
    (( UI_PHASE_ERRS > 0 )) && details+="$(_ui_plural "$UI_PHASE_ERRS" "fout" "fouten") $UI_GLYPH_DOT "
    details+="$(_ui_duration "$elapsed")"

    ui_release_terminal
    printf "  ${color}%s${_RESET} %s  %-24s ${_DIM}%s${_RESET}\n" "$glyph" "$UI_PHASE_NUM" "$UI_PHASE_TITLE" "$details" >&3

    UI_TOTAL_WARNS=$((UI_TOTAL_WARNS + UI_PHASE_WARNS))
    UI_TOTAL_ERRS=$((UI_TOTAL_ERRS + UI_PHASE_ERRS))
    UI_TOTAL_PKGS=$((UI_TOTAL_PKGS + UI_PHASE_PKGS))
    UI_TOTAL_DRY=$((UI_TOTAL_DRY + UI_PHASE_DRY))
    UI_PHASES_DONE=$((UI_PHASES_DONE + 1))
    UI_PHASE_ID=""
    UI_PHASE_TITLE=""
}

# Aanroepen na phase_run.
log_phase_done() {
    _ui_phase_finish
    _log_raw "=== FASE KLAAR: ${1:-} ==="
}

set_phase_progress() {
    INSTALL_TOTAL_PHASES="${1:-0}"
    INSTALL_CURRENT_PHASE="${2:-0}"
    export INSTALL_TOTAL_PHASES INSTALL_CURRENT_PHASE
}

_ui_clear() {
    if [[ "$INSTALL_UI_MODE" == "true" ]]; then
        printf '\033[H\033[2J\033[3J'
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
    local rc=$?
    ui_release_terminal
    _ui_header_teardown
    _restore_kernel_console_loglevel
    if [[ "${INSTALL_UI_MODE:-false}" == "true" && $rc -ne 0 ]]; then
        printf "\n${_RED}${_BOLD}Installatie mislukt (code %s).${_RESET}\n" "$rc" >&4
        if [[ "$INSTALL_UI_QUIET" == "true" && -s "$LOG_FILE" ]]; then
            printf "${_DIM}Laatste regels uit het log:${_RESET}\n" >&4
            tail -n 12 "$LOG_FILE" | sed 's/^/  /' >&4
        fi
        printf "${_BOLD}Log: %s${_RESET}\n\n" "$LOG_FILE" >&4
        [[ -t 0 ]] && read -r -p "Druk Enter om te sluiten..." _ 2>&4
    fi
}

install_ui_finish_screen() {
    [[ "${INSTALL_UI_MODE:-false}" == "true" ]] || return 0
    [[ "$INSTALL_UI_QUIET" == "true" ]] && return 0
    _ui_clear
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
    local percent=0
    (( total > 0 )) && percent=$(( current * 100 / total ))
    printf "[%s] %3d%%" "$(_ui_bar "$total" "$current" 30)" "$percent"
}

_render_detect_summary() {
    printf "GPU:%s Laptop:%s Touch:%s Tablet:%s Finger:%s" \
        "${DETECT_GPU:-?}" \
        "${DETECT_IS_LAPTOP:-false}" \
        "${DETECT_HAS_TOUCHSCREEN:-false}" \
        "${ENABLE_TABLET_MODE:-false}" \
        "${DETECT_HAS_FINGERPRINT:-false}"
}

# Terminalgrootte via fd 3: in $(...) is stdout een pipe en geeft tput 80x24.
_ui_term_size() {
    local size rows="" cols=""
    size="$(stty size <&3 2>/dev/null || true)"
    read -r rows cols <<< "$size"
    if [[ "$1" == "rows" ]]; then
        [[ "$rows" =~ ^[0-9]+$ ]] || rows="$(_tput_safe lines)"
        printf '%s' "$rows"
    else
        [[ "$cols" =~ ^[0-9]+$ ]] || cols="$(_tput_safe cols)"
        printf '%s' "$cols"
    fi
}

_progress_line_columns() {
    local cols
    cols="$(_ui_term_size cols)"
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

    if [[ "$INSTALL_UI_QUIET" == "true" ]]; then
        _ui_phase_finish
        ui_release_terminal
        if (( UI_PHASES_DONE == 0 )); then
            printf "\n  ${_BOLD}Installatie${_RESET} ${_DIM}%s${_RESET}\n\n" "$(_ui_plural "$total" "fase" "fases")" >&3
        fi
        UI_PHASE_ID="$name"
        UI_PHASE_NUM="${name%%_*}"
        [[ "$UI_PHASE_NUM" =~ ^[0-9]+$ ]] || UI_PHASE_NUM="$(printf '%02d' "$current")"
        UI_PHASE_TITLE="$(_ui_phase_title "$name")"
        UI_PHASE_START=$SECONDS
        UI_PHASE_WARNS=0
        UI_PHASE_ERRS=0
        UI_PHASE_PKGS=0
        UI_PHASE_DRY=0
        UI_PHASE_HEADER_SHOWN=false
        INSTALL_LAST_TASK_MSG="starten..."
        _ui_live_draw
    elif [[ "$INSTALL_UI_MODE" == "true" ]]; then
        _ui_clear
        print_banner
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
    if [[ "$INSTALL_UI_QUIET" == "true" ]]; then
        _ui_live_draw "$msg"
        return 0
    fi
    if [[ "$INSTALL_UI_MODE" != "true" || "${INSTALL_VERBOSE_COMMANDS:-false}" == "true" ]]; then
        log_step "$msg"
        return 0
    fi
    _progress_line_print ".." "$msg"
}

_progress_task_tick() {
    local spinner="${1:-.}"
    local msg="${2:-$INSTALL_LAST_TASK_MSG}"
    if [[ "$INSTALL_UI_QUIET" == "true" ]]; then
        UI_SPIN_IDX=$((UI_SPIN_IDX + 1))
        _ui_live_draw "$msg"
        return 0
    fi
    if [[ "$INSTALL_UI_MODE" != "true" || "${INSTALL_VERBOSE_COMMANDS:-false}" == "true" ]]; then
        return 0
    fi
    _progress_line_print "$spinner" "$msg"
}

_progress_task_end() {
    local rc="${1:-0}"
    local msg="${2:-$INSTALL_LAST_TASK_MSG}"
    if [[ "$INSTALL_UI_QUIET" == "true" ]]; then
        if [[ "$rc" -eq 0 ]]; then
            _log_raw "TASK OK: $msg"
        else
            _log_raw "TASK FAIL($rc): $msg"
            UI_PHASE_ERRS=$((UI_PHASE_ERRS + 1))
            _ui_persist "$_RED" "$UI_GLYPH_FAIL" "$msg"
        fi
        return 0
    fi
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
    ui_release_terminal
    # Vanuit de Update Runner: geen banner, die heeft al een kop.
    [[ "$INSTALL_UI_QUIET" == "true" && "${KINGSTRA_UI_EMBEDDED:-false}" == "true" ]] && return 0
    # Vaste kop: banner staat bovenaan het scherm, ook na bootstrap.sh.
    _ui_header_setup && return 0
    # bootstrap.sh heeft de banner al getoond.
    [[ "${KINGSTRA_BANNER_SHOWN:-false}" == "true" ]] && return 0
    _print_banner_art
}

_print_banner_art() {
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
    ui_release_terminal
    if [[ "$INSTALL_UI_QUIET" == "true" ]]; then
        [[ "${KINGSTRA_UI_EMBEDDED:-false}" == "true" ]] && return 0
        local hw=() extras=()
        [[ "${DETECT_IS_LAPTOP:-false}" == "true" ]] && hw+=("laptop")
        [[ "${DETECT_HAS_TOUCHPAD:-false}" == "true" ]] && hw+=("touchpad")
        [[ "${DETECT_HAS_TOUCHSCREEN:-false}" == "true" ]] && hw+=("touchscreen")
        [[ "${ENABLE_TABLET_MODE:-false}" == "true" ]] && hw+=("tabletmodus")
        [[ "${DETECT_HAS_FINGERPRINT:-false}" == "true" ]] && hw+=("vingerafdruk")
        "${DRY_RUN:-false}" && extras+=("dry-run")
        extras+=("AUR: ${AUR_HELPER:-geen}")

        local sep=" $UI_GLYPH_DOT "
        local hw_text="${DETECTED_DISTRO:-onbekend}${sep}GPU ${DETECT_GPU:-onbekend}"
        local item
        for item in "${hw[@]+"${hw[@]}"}"; do hw_text+="$sep$item"; done
        local extra_text="${extras[0]}"
        for item in "${extras[@]:1}"; do extra_text+="$sep$item"; done

        printf "  ${_BOLD}Systeem${_RESET}  %s\n" "$hw_text" >&3
        printf "  ${_BOLD}Opties${_RESET}   %s\n" "$extra_text" >&3
        printf "  ${_BOLD}Back-up${_RESET}  ${_DIM}%s${_RESET}\n" "${BACKUP_DIR:-wordt aangemaakt}" >&3
        printf "  ${_BOLD}Log${_RESET}      ${_DIM}%s${_RESET}\n\n" "$LOG_FILE" >&3
        return 0
    fi
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
    if [[ "$INSTALL_UI_QUIET" == "true" ]]; then
        _ui_phase_finish
        ui_release_terminal
        local total="${INSTALL_TOTAL_PHASES:-0}"
        (( total > 0 )) || total=1
        local status="${_GREEN}${_BOLD}Installatie voltooid${_RESET}"
        (( UI_TOTAL_ERRS > 0 )) && status="${_YELLOW}${_BOLD}Installatie klaar met fouten${_RESET}"
        local details
        details="$(_ui_duration "$SECONDS")"
        (( UI_TOTAL_PKGS > 0 )) && details+=" $UI_GLYPH_DOT $(_ui_plural "$UI_TOTAL_PKGS" "pakket" "pakketten") geïnstalleerd"
        (( UI_TOTAL_WARNS > 0 )) && details+=" $UI_GLYPH_DOT $(_ui_plural "$UI_TOTAL_WARNS" "waarschuwing" "waarschuwingen")"
        (( UI_TOTAL_ERRS > 0 )) && details+=" $UI_GLYPH_DOT $(_ui_plural "$UI_TOTAL_ERRS" "fout" "fouten")"
        if (( UI_TOTAL_DRY > 0 )); then
            status="${_BOLD}Dry-run klaar${_RESET}"
            details+=" $UI_GLYPH_DOT $(_ui_plural "$UI_TOTAL_DRY" "actie" "acties") in het log (of draai met --verbose)"
        fi
        if [[ "$UI_HEADER" == "true" ]]; then
            # De kop blijft staan; _install_log_cleanup heft de regio op.
            _ui_live_draw "klaar"
        else
            printf "\n  ${_GREEN}%s${_RESET} ${_BOLD}%3d%%${_RESET}\n" "$(_ui_bar "$total" "$total")" 100 >&3
        fi
        printf "\n  %b  ${_DIM}%s${_RESET}\n" "$status" "$details" >&3
        printf "  ${_DIM}Volledige uitvoer: %s${_RESET}\n\n" "$LOG_FILE" >&3
        # Wat hierna komt (instructies, herstartvraag) gewoon tonen.
        INSTALL_UI_QUIET=false
        if [[ -n "${INSTALL_AFTER_SUMMARY:-}" ]] && declare -f "$INSTALL_AFTER_SUMMARY" >/dev/null; then
            "$INSTALL_AFTER_SUMMARY"
        fi
        return 0
    fi
    echo ""
    printf "${_GREEN}${_BOLD}══════════════════════════════════════════════${_RESET}\n"
    printf "${_GREEN}${_BOLD}  Installatie voltooid.${_RESET}\n"
    printf "${_GREEN}${_BOLD}══════════════════════════════════════════════${_RESET}\n"
    printf "  Log: %s\n\n" "$LOG_FILE"
}
