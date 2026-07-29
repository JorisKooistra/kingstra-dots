#!/usr/bin/env bash
# Vergrendel eerst betrouwbaar en start daarna pas system suspend.
set -u

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
LOCK_SCRIPT="$CONFIG_HOME/hypr/scripts/lock.sh"
RESUME_SCRIPT="$CONFIG_HOME/hypr/scripts/resume-display.sh"

lock_running() {
    pgrep -f "quickshell.*Lock\\.qml" >/dev/null 2>&1 ||
        pgrep -x hyprlock >/dev/null 2>&1
}

if ! lock_running; then
    if [[ -x "$LOCK_SCRIPT" ]]; then
        "$LOCK_SCRIPT"
    else
        loginctl lock-session >/dev/null 2>&1 || true
    fi
fi

# Geef de session-lock surface tijd om te mappen voordat processen bevriezen.
for _ in {1..10}; do
    lock_running && break
    sleep 0.1
done
sleep 0.2

systemctl suspend
status=$?

# Ook handmatige suspend blijft zo beschermd als hypridle niet actief is.
if [[ -x "$RESUME_SCRIPT" ]]; then
    "$RESUME_SCRIPT"
fi

exit "$status"
