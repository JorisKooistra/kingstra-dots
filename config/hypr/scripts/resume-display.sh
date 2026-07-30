#!/usr/bin/env bash
# Herstel Hyprland-uitvoer na DPMS-off of system suspend.
#
# Een enkele directe `hyprctl dispatch dpms on` kan tijdens NVIDIA-resume te
# vroeg komen. Bovendien wisselt nvidia-sleep.sh tijdelijk naar VT63. Wacht bij
# een echte system-resume daarom tot systemd/NVIDIA klaar zijn, activeer de
# Hyprland-sessie opnieuw en forceer eenmaal een nieuwe DRM-modeset met een
# korte DPMS power-cycle.
set -u

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
LOG_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/kingstra"
LOG_FILE="$LOG_DIR/resume-display.log"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
RESET_LOCK="$RUNTIME_DIR/kingstra-resume-display.lock"
RESET_STAMP="$RUNTIME_DIR/kingstra-resume-display.stamp"
MODE="${1:-full}"

mkdir -p "$LOG_DIR"

log() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG_FILE"
}

run_hyprctl() {
    local output
    local action="$1"

    if ! command -v hyprctl >/dev/null 2>&1; then
        log "hyprctl ontbreekt; DPMS-herstel overgeslagen"
        return 1
    fi

    if command -v timeout >/dev/null 2>&1; then
        output="$(timeout --kill-after=1 4 hyprctl dispatch dpms "$action" 2>&1)" || {
            log "DPMS ${action} mislukt: ${output:-geen uitvoer}"
            return 1
        }
    else
        output="$(hyprctl dispatch dpms "$action" 2>&1)" || {
            log "DPMS ${action} mislukt: ${output:-geen uitvoer}"
            return 1
        }
    fi

    log "DPMS ${action} gelukt"
}

restore_once() {
    run_hyprctl on
}

wait_for_system_resume() {
    local state=""

    # NVIDIA's systemd-sleep helper herstelt eerst het videogeheugen en VT.
    # User-processen kunnen al eerder ontwaken; wacht daarom op het einde van
    # systemd-suspend.service voordat we een nieuwe modeset aanvragen.
    if command -v systemctl >/dev/null 2>&1; then
        for _ in {1..48}; do
            state="$(systemctl show --property=ActiveState --value systemd-suspend.service 2>/dev/null || true)"
            if [[ -z "$state" ]]; then
                # Als D-Bus tijdens de vroege resume nog niet antwoordt, is
                # direct doorgaan juist het onveilige pad. NVIDIA had op deze
                # machine bij de laatste wake circa vijf seconden nodig.
                log "systemd-resumestatus nog niet leesbaar; vaste wachttijd gebruikt"
                sleep 5
                break
            fi
            case "$state" in
                active|activating|deactivating|reloading)
                    sleep 0.25
                    ;;
                *)
                    break
                    ;;
            esac
        done
    fi

    # nvidia-resume.service wordt direct na systemd-suspend.service gestart.
    sleep 0.75
}

activate_hyprland_session() {
    local output

    [[ -n "${XDG_SESSION_ID:-}" ]] || {
        log "sessie-activatie overgeslagen; XDG_SESSION_ID ontbreekt"
        return 0
    }
    command -v loginctl >/dev/null 2>&1 || return 0

    if command -v timeout >/dev/null 2>&1; then
        output="$(timeout --kill-after=1 4 loginctl activate "$XDG_SESSION_ID" 2>&1)" || {
            log "sessie ${XDG_SESSION_ID} activeren mislukt: ${output:-geen uitvoer}"
            return 1
        }
    else
        output="$(loginctl activate "$XDG_SESSION_ID" 2>&1)" || {
            log "sessie ${XDG_SESSION_ID} activeren mislukt: ${output:-geen uitvoer}"
            return 1
        }
    fi

    log "Hyprland-sessie ${XDG_SESSION_ID} opnieuw geactiveerd"
}

reset_outputs_once() {
    local now last=0 active_vt="onbekend"

    exec 9>"$RESET_LOCK"
    if command -v flock >/dev/null 2>&1 && ! flock -n 9; then
        log "DPMS power-cycle overgeslagen; herstel draait al"
        return 0
    fi

    now="$(date +%s)"
    if [[ -r "$RESET_STAMP" ]]; then
        read -r last <"$RESET_STAMP" || last=0
    fi
    if [[ "$last" =~ ^[0-9]+$ ]] && (( now >= last && now - last < 10 )); then
        log "DPMS power-cycle overgeslagen; recent al uitgevoerd"
        return 0
    fi

    if [[ -r /sys/class/tty/tty0/active ]]; then
        read -r active_vt </sys/class/tty/tty0/active || true
    fi
    log "post-NVIDIA display-reset gestart (actieve VT: ${active_vt})"

    activate_hyprland_session || true
    run_hyprctl off || true
    sleep 0.35
    if run_hyprctl on; then
        printf '%s\n' "$now" >"$RESET_STAMP"
        log "post-NVIDIA display-reset voltooid"
        return 0
    fi

    return 1
}

spawn_attempt() {
    local delay="$1"
    local action="${2:-on}"

    if command -v setsid >/dev/null 2>&1; then
        setsid -f "$0" --attempt "$delay" "$action" >/dev/null 2>&1
    else
        nohup "$0" --attempt "$delay" "$action" >/dev/null 2>&1 &
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
    case "${3:-on}" in
        reset)
            wait_for_system_resume
            reset_outputs_once
            ;;
        *)
            restore_once
            ;;
    esac
    exit $?
fi

log "display-herstel gestart (${MODE})"
restore_once || true

if [[ "$MODE" != "--display-only" ]]; then
    # Een tweede `dpms on` is geen nieuwe modeset wanneer de eerste te vroeg
    # kwam. De power-cycle na NVIDIA-resume forceert dat wel. De tweede poging
    # is alleen een fallback; lock + timestamp voorkomen dubbele flicker.
    spawn_attempt 1 reset
    spawn_attempt 6 reset
    spawn_attempt 10 on
    start_full_resume_fix
else
    # Gewone idle/DPMS-wakes hoeven niet te flikkeren door een power-cycle.
    spawn_attempt 1 on
    spawn_attempt 3 on
fi

exit 0
