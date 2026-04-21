#!/usr/bin/env bash
# =============================================================================
# fingerprint-first-run.sh - Start fprintd enrollment on first Hyprland login
# =============================================================================
set -euo pipefail

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/kingstra/state"
PENDING_FILE="$STATE_DIR/fingerprint-enroll.pending"
DONE_FILE="$STATE_DIR/fingerprint-enroll.done"
ATTEMPTS_FILE="$STATE_DIR/fingerprint-enroll.attempts"
LOCK_FILE="/tmp/kingstra-fingerprint-first-run.lock"
LOG_PREFIX="[kingstra-fingerprint]"

_log() {
    echo "$LOG_PREFIX $*" | systemd-cat --identifier=kingstra-fingerprint 2>/dev/null || echo "$LOG_PREFIX $*"
}

_notify() {
    notify-send --app-name="kingstra" --icon=dialog-password "$@" 2>/dev/null || true
}

_fprint_output_has_enrolled_finger() {
    local output="$1"

    [[ -n "$output" ]] || return 1

    if printf '%s\n' "$output" | grep -qiE 'no fingers enrolled|found 0 (enrolled )?(fingers|prints)|no enrolled prints'; then
        return 1
    fi

    printf '%s\n' "$output" | grep -Eq '^[[:space:]]*-[[:space:]]*[^[:space:]].*$|found [1-9][0-9]* (enrolled )?(fingers|prints)'
}

_has_enrolled_finger() {
    local output
    output="$(timeout 7 fprintd-list "$USER" 2>/dev/null || true)"
    _fprint_output_has_enrolled_finger "$output"
}

_has_fprint_device() {
    local output
    output="$(timeout 7 fprintd-list "$USER" 2>&1 || true)"
    [[ -n "$output" ]] || return 1
    ! printf '%s\n' "$output" | grep -qiE 'no devices|no such device|not found'
}

_mark_done() {
    mkdir -p "$STATE_DIR"
    {
        printf 'completed_at=%s\n' "$(date -Is)"
        printf 'user=%s\n' "$USER"
    } > "$DONE_FILE"
    rm -f "$PENDING_FILE" "$ATTEMPTS_FILE"
}

_terminal_session() {
    clear 2>/dev/null || true
    printf '%s\n\n' "Kingstra fingerprint instellen"
    printf '%s\n' "Er is een vingerafdrukscanner gedetecteerd."
    printf '%s\n' "Je kunt nu een vinger inschrijven voor sudo, SDDM en hyprlock."
    printf '\n%s' "Druk Enter om fprintd-enroll te starten, of sluit dit venster om later opnieuw te proberen."
    read -r _ || true
    printf '\n'

    if fprintd-enroll "$USER"; then
        _mark_done
        _notify "Fingerprint ingesteld" "Vingerafdruk is geregistreerd voor $USER"
        printf '\n%s\n' "Klaar. Fingerprint is geregistreerd."
    else
        _notify "Fingerprint niet ingesteld" "fprintd-enroll is afgebroken of mislukt"
        printf '\n%s\n' "Niet gelukt. Dit venster mag dicht; bij de volgende login wordt het opnieuw geprobeerd."
    fi

    printf '\n%s' "Druk Enter om te sluiten."
    read -r _ || true
}

_launch_terminal() {
    local self="$1"
    local terminal="${TERMINAL:-}"

    if [[ -n "$terminal" ]] && command -v "$terminal" >/dev/null 2>&1; then
        "$terminal" -e "$self" --terminal >/dev/null 2>&1 &
        return 0
    fi

    if command -v kitty >/dev/null 2>&1; then
        kitty --title "Fingerprint instellen" "$self" --terminal >/dev/null 2>&1 &
        return 0
    fi

    if command -v foot >/dev/null 2>&1; then
        foot --title "Fingerprint instellen" "$self" --terminal >/dev/null 2>&1 &
        return 0
    fi

    if command -v alacritty >/dev/null 2>&1; then
        alacritty --title "Fingerprint instellen" -e "$self" --terminal >/dev/null 2>&1 &
        return 0
    fi

    if command -v wezterm >/dev/null 2>&1; then
        wezterm start -- "$self" --terminal >/dev/null 2>&1 &
        return 0
    fi

    if command -v xterm >/dev/null 2>&1; then
        xterm -T "Fingerprint instellen" -e "$self" --terminal >/dev/null 2>&1 &
        return 0
    fi

    return 1
}

main() {
    mkdir -p "$STATE_DIR"

    if [[ "${1:-}" == "--terminal" ]]; then
        _terminal_session
        return 0
    fi

    [[ -f "$PENDING_FILE" ]] || return 0
    [[ ! -f "$DONE_FILE" ]] || return 0
    command -v fprintd-enroll >/dev/null 2>&1 || return 0
    command -v fprintd-list >/dev/null 2>&1 || return 0

    exec 9>"$LOCK_FILE"
    flock -n 9 || return 0

    sleep 6

    if _has_enrolled_finger; then
        _mark_done
        _log "Fingerprint enrollment bestaat al; first-run gemarkeerd als klaar"
        return 0
    fi

    if ! _has_fprint_device; then
        _log "Geen bruikbaar fprintd-device gevonden bij first-run"
        return 0
    fi

    local attempts
    attempts="$(cat "$ATTEMPTS_FILE" 2>/dev/null || echo 0)"
    attempts=$((attempts + 1))
    printf '%s\n' "$attempts" > "$ATTEMPTS_FILE"

    if (( attempts > 5 )); then
        _log "Fingerprint first-run niet meer automatisch geopend na 5 pogingen"
        return 0
    fi

    if _launch_terminal "$(readlink -f "$0")"; then
        _notify "Fingerprint instellen" "Volg de stappen in het terminalvenster"
        _log "Fingerprint enrollment terminal gestart"
    else
        _notify "Fingerprint instellen" "Open handmatig: fprintd-enroll"
        _log "Geen terminal gevonden voor fingerprint enrollment"
    fi
}

main "$@"
