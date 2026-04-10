#!/usr/bin/env bash
set -u

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
LOCK_QML="$CONFIG_HOME/quickshell/Lock.qml"

fingerprint_lock_available() {
    command -v hyprlock >/dev/null 2>&1 || return 1
    command -v fprintd-verify >/dev/null 2>&1 || return 1
    grep -Eq '^[[:space:]]*auth[[:space:]]+sufficient[[:space:]]+pam_fprintd\.so([[:space:]].*)?$' /etc/pam.d/hyprlock 2>/dev/null
}

# Prevent duplicate lock instances
if pgrep -f "quickshell.*Lock.qml" >/dev/null 2>&1; then
    exit 0
fi
if pgrep -x hyprlock >/dev/null 2>&1; then
    exit 0
fi

# Prefer hyprlock when fingerprint auth is available there.
if fingerprint_lock_available; then
    hyprlock >/dev/null 2>&1 &
    exit 0
fi

# Preferred: Quickshell lock UI
if command -v quickshell >/dev/null 2>&1 && [[ -f "$LOCK_QML" ]]; then
    quickshell -p "$LOCK_QML" >/dev/null 2>&1 &
    sleep 0.2
    if pgrep -f "quickshell.*Lock.qml" >/dev/null 2>&1; then
        exit 0
    fi
fi

# Fallback: hyprlock
if command -v hyprlock >/dev/null 2>&1; then
    hyprlock >/dev/null 2>&1 &
    exit 0
fi

# Last fallback: ask logind to lock session
if command -v loginctl >/dev/null 2>&1; then
    loginctl lock-session >/dev/null 2>&1 || true
fi

exit 0
