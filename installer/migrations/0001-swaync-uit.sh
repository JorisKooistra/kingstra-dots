#!/usr/bin/env bash
# SwayNC is vervangen door Quickshell-meldingen. Stop een achtergebleven
# swaync-proces en zet een eventuele user-service uit. Draait één keer.

migration_run() {
    if pgrep -x swaync >/dev/null 2>&1; then
        pkill -x swaync || true
        log_ok "SwayNC gestopt"
    fi
    if systemctl --user is-enabled swaync.service >/dev/null 2>&1; then
        systemctl --user disable --now swaync.service >/dev/null 2>&1 || true
        log_ok "swaync.service uitgezet"
    fi
    return 0
}
