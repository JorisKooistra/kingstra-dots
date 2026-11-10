#!/usr/bin/env bash
# Super+Ctrl+Tab: opent de vensterwisselaar, of schuift één venster verder
# als hij al open is (Hyprland vangt de toets ook dan af).
if [[ "$(cat /tmp/qs_active_widget 2>/dev/null)" == "switcher" ]]; then
    date +%s%N > /tmp/kingstra-switcher-step
else
    exec bash "$HOME/.config/hypr/scripts/qs_manager.sh" open switcher
fi
