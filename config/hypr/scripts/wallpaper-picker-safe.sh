#!/usr/bin/env bash
set -u

if command -v skwd >/dev/null 2>&1; then
    systemctl --user start skwd-daemon.service >/dev/null 2>&1 || true
    if skwd wall toggle >/dev/null 2>&1; then
        exit 0
    fi
fi

if command -v kingstra-wallpaper >/dev/null 2>&1; then
    kingstra-wallpaper pick
    exit $?
fi

notify-send "Wallpaper" "Geen wallpaper-picker gevonden (skwd of kingstra-wallpaper)" 2>/dev/null || true
exit 1
