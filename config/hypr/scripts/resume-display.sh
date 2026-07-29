#!/usr/bin/env bash
# Herstel Hyprland-uitvoer na DPMS-off of system suspend.
#
# Een enkele directe `hyprctl dispatch dpms on` kan tijdens NVIDIA-resume te
# vroeg komen. Daarom volgen er nog enkele losgekoppelde pogingen zodra de
# driver en compositor verder zijn hersteld.
set -u

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
LOG_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/kingstra"
LOG_FILE="$LOG_DIR/resume-display.log"
MODE="${1:-full}"

mkdir -p "$LOG_DIR"

log() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG_FILE"
}

restore_once() {
    local output

    if ! command -v hyprctl >/dev/null 2>&1; then
        log "hyprctl ontbreekt; DPMS-herstel overgeslagen"
        return 1
    fi

    if command -v timeout >/dev/null 2>&1; then
        output="$(timeout --kill-after=1 4 hyprctl dispatch dpms on 2>&1)" || {
            log "DPMS on mislukt: ${output:-geen uitvoer}"
            return 1
        }
    else
        output="$(hyprctl dispatch dpms on 2>&1)" || {
            log "DPMS on mislukt: ${output:-geen uitvoer}"
            return 1
        }
    fi

    log "DPMS on gelukt"
}

spawn_attempt() {
    local delay="$1"

    if command -v setsid >/dev/null 2>&1; then
        setsid -f "$0" --attempt "$delay" >/dev/null 2>&1
    else
        nohup "$0" --attempt "$delay" >/dev/null 2>&1 &
    fi
}

start_full_resume_fix() {
    local fix_script="$CONFIG_HOME/hypr/scripts/resume-fix.sh"

    if command -v systemctl >/dev/null 2>&1 &&
       systemctl --user start --no-block kingstra-resume.service >/dev/null 2>&1; then
        log "volledige resume-service gestart"
        return
    fi

    if [[ -x "$fix_script" ]]; then
        if command -v setsid >/dev/null 2>&1; then
            setsid -f "$fix_script" >/dev/null 2>&1
        else
            nohup "$fix_script" >/dev/null 2>&1 &
        fi
        log "volledige resume-fix direct gestart (service niet beschikbaar)"
    fi
}

if [[ "$MODE" == "--attempt" ]]; then
    sleep "${2:-1}"
    restore_once
    exit $?
fi

log "display-herstel gestart (${MODE})"
restore_once || true
spawn_attempt 1
spawn_attempt 3
spawn_attempt 6

if [[ "$MODE" != "--display-only" ]]; then
    start_full_resume_fix
fi

exit 0
