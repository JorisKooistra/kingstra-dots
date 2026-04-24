#!/usr/bin/env bash
# =============================================================================
# common.sh — Gedeelde hulpfuncties
# =============================================================================

# Zorg dat REPO_ROOT altijd beschikbaar is
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# ---------------------------------------------------------------------------
# Commando's uitvoeren (dry-run bewust)
# ---------------------------------------------------------------------------
run_cmd() {
    if "${DRY_RUN:-false}"; then
        if [[ -n "${INSTALL_NEXT_RUN_LABEL:-}" ]]; then
            log_dry "${INSTALL_NEXT_RUN_LABEL}: $*"
        else
            log_dry "$*"
        fi
        return 0
    fi

    local cmd_pretty="$*"
    local task_msg="${INSTALL_NEXT_RUN_LABEL:-$cmd_pretty}"
    local first_arg="${1:-}"
    local first_base
    first_base="$(basename "$first_arg" 2>/dev/null || echo "$first_arg")"

    local can_quiet=true
    if [[ "${INSTALL_UI_MODE:-false}" != "true" || "${INSTALL_VERBOSE_COMMANDS:-false}" == "true" ]]; then
        can_quiet=false
    fi

    case "$first_base" in
        sudo)
            # Alleen stil uitvoeren als sudo-credentials al geldig zijn.
            sudo -n true >/dev/null 2>&1 || can_quiet=false
            ;;
        chsh|passwd)
            can_quiet=false
            ;;
    esac

    if [[ "$can_quiet" == "true" ]]; then
        local tmp_out rc pid
        local spinner='-\|/'
        local i=0
        local ch="."

        tmp_out="$(mktemp)"
        _progress_task_start "$task_msg"
        _log_raw "COMMAND: $cmd_pretty"

        "$@" >"$tmp_out" 2>&1 &
        pid=$!

        while kill -0 "$pid" 2>/dev/null; do
            ch="${spinner:i%4:1}"
            _progress_task_tick "$ch" "$task_msg"
            i=$((i + 1))
            sleep 0.12
        done

        if wait "$pid"; then
            rc=0
        else
            rc=$?
        fi

        if [[ -s "$tmp_out" ]]; then
            cat "$tmp_out" >> "$LOG_FILE"
        fi

        _progress_task_end "$rc" "$task_msg"
        if [[ "$rc" -ne 0 ]]; then
            log_error "Commando mislukt (exit $rc): $cmd_pretty"
            if [[ -s "$tmp_out" ]]; then
                log_error "Laatste uitvoer:"
                tail -n 20 "$tmp_out" >&2
            else
                log_error "Geen uitvoer ontvangen. Volledige context: $LOG_FILE"
            fi
            rm -f "$tmp_out"
            return "$rc"
        fi
        rm -f "$tmp_out"
        return 0
    fi

    # Fallback: normale uitvoer (bijv. sudo prompt, AUR helper interactie)
    log_step "$task_msg"
    _log_raw "COMMAND: $cmd_pretty"
    "$@"
}

# ---------------------------------------------------------------------------
# Directories aanmaken
# ---------------------------------------------------------------------------
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        run_cmd mkdir -p "$dir"
    fi
}

# ---------------------------------------------------------------------------
# Controleer of een commando bestaat
# ---------------------------------------------------------------------------
has_cmd() {
    command -v "$1" &>/dev/null
}

# ---------------------------------------------------------------------------
# Live sessie bijwerken (dry-run bewust)
# ---------------------------------------------------------------------------
hyprland_live() {
    has_cmd hyprctl || return 1
    hyprctl monitors -j >/dev/null 2>&1
}

reload_hyprland_live() {
    local reason="${1:-configwijzigingen}"

    if "${DRY_RUN:-false}"; then
        log_dry "Hyprland zou worden herladen voor: $reason"
        return 0
    fi

    if ! has_cmd hyprctl; then
        log_info "Hyprland reload overgeslagen: hyprctl is niet beschikbaar."
        return 0
    fi

    if ! hyprland_live; then
        log_info "Hyprland reload overgeslagen: geen live Hyprland-sessie bereikbaar."
        return 0
    fi

    if hyprctl reload >/dev/null 2>&1; then
        log_ok "Hyprland herladen: $reason"
    else
        log_warn "Hyprland reload niet gelukt; herlaad handmatig als deze wijziging nog niet actief is."
    fi
}

start_quickshell_config_live() {
    local config="$1"
    local label="${2:-Quickshell $config}"

    if "${DRY_RUN:-false}"; then
        log_dry "$label zou live worden gestart: qs --no-duplicate --daemonize -c $config"
        return 0
    fi

    if ! has_cmd qs; then
        log_info "$label niet live gestart: qs is niet beschikbaar."
        return 0
    fi

    if ! hyprland_live; then
        log_info "$label niet live gestart: geen live Hyprland-sessie bereikbaar."
        return 0
    fi

    if qs --no-duplicate --daemonize -c "$config" >/dev/null 2>&1; then
        log_ok "$label live gestart"
    else
        log_warn "$label kon niet live worden gestart."
    fi
}

start_quickshell_path_live() {
    local path="$1"
    local label="${2:-Quickshell $path}"

    if "${DRY_RUN:-false}"; then
        log_dry "$label zou live worden gestart: qs --no-duplicate --daemonize -p $path"
        return 0
    fi

    if ! has_cmd qs; then
        log_info "$label niet live gestart: qs is niet beschikbaar."
        return 0
    fi

    if ! hyprland_live; then
        log_info "$label niet live gestart: geen live Hyprland-sessie bereikbaar."
        return 0
    fi

    if qs --no-duplicate --daemonize -p "$path" >/dev/null 2>&1; then
        log_ok "$label live gestart"
    else
        log_warn "$label kon niet live worden gestart."
    fi
}

# ---------------------------------------------------------------------------
# Veilig een bestand aanraken (dry-run bewust)
# ---------------------------------------------------------------------------
safe_touch() {
    local file="$1"
    ensure_dir "$(dirname "$file")"
    run_cmd touch "$file"
}

# ---------------------------------------------------------------------------
# Profiel inladen
# ---------------------------------------------------------------------------
load_profile() {
    local profile="${1:-default}"
    local profile_file="$REPO_ROOT/installer/profiles/${profile}.conf"

    if [[ -f "$profile_file" ]]; then
        log_info "Profiel ingeladen: $profile"
        # shellcheck source=/dev/null
        source "$profile_file"
    else
        log_warn "Profielbestand niet gevonden: $profile_file — standaardinstellingen worden gebruikt"
    fi
}
