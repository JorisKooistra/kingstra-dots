#!/usr/bin/env bash
set -u

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
LOCK_QML="$CONFIG_HOME/quickshell/Lock.qml"
LOG_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/kingstra"
LOG_FILE="$LOG_DIR/lock.log"

mkdir -p "$LOG_DIR"

log() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG_FILE"
}

fingerprint_lock_available() {
    command -v hyprlock >/dev/null 2>&1 || return 1
    command -v fprintd-verify >/dev/null 2>&1 || return 1
    grep -Eq '^[[:space:]]*auth[[:space:]]+sufficient[[:space:]]+pam_fprintd\.so([[:space:]].*)?$' /etc/pam.d/hyprlock 2>/dev/null
}

start_quickshell_lock() {
    command -v quickshell >/dev/null 2>&1 || return 1
    [[ -f "$LOCK_QML" ]] || return 1

    log "starting quickshell lock: $LOCK_QML"
    quickshell --no-duplicate -p "$LOCK_QML" >>"$LOG_FILE" 2>&1 &
    sleep 0.35

    pgrep -f "quickshell.*Lock\.qml" >/dev/null 2>&1
}

start_hyprlock() {
    command -v hyprlock >/dev/null 2>&1 || return 1

    log "starting hyprlock"
    hyprlock >>"$LOG_FILE" 2>&1 &
    sleep 0.35

    pgrep -x hyprlock >/dev/null 2>&1
}

# Prevent duplicate lock instances
if pgrep -f "quickshell.*Lock\.qml" >/dev/null 2>&1; then
    exit 0
fi
if pgrep -x hyprlock >/dev/null 2>&1; then
    exit 0
fi

# Prefer Quickshell lock UI, using the same PAM service as hyprlock.
if start_quickshell_lock; then
    exit 0
fi

if fingerprint_lock_available; then
    log "quickshell lock did not stay running; trying hyprlock with fingerprint-capable PAM"
else
    log "quickshell lock did not stay running; trying hyprlock fallback"
fi

if start_hyprlock; then
    exit 0
fi

# Last fallback: ask logind to lock session
if command -v loginctl >/dev/null 2>&1; then
    log "hyprlock did not stay running; asking logind to lock session"
    loginctl lock-session >>"$LOG_FILE" 2>&1 || true
fi

exit 0
