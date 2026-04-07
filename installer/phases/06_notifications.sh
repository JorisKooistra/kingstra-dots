#!/usr/bin/env bash
# =============================================================================
# Fase 06 — Notifications en control center (SwayNC)
# =============================================================================

phase_run() {
    log_step "SwayNC installeren..."
    pacman_install swaynotificationcenter

    log_step "SwayNC config deployen..."
    deploy_config "swaync"

    log_step "SwayNC herstarten als sessie actief is..."
    _phase06_restart_swaync

    log_step "Fase 06 valideren..."
    validate_cmd swaync
    validate_cmd swaync-client
    validate_file "$HOME/.config/swaync/config.jsonc" "swaync/config.jsonc"
    validate_file "$HOME/.config/swaync/style.css"    "swaync/style.css"
    validate_report

    log_ok "Fase 06 voltooid — SwayNC staat."
}

_phase06_restart_swaync() {
    if "${DRY_RUN:-false}"; then
        log_dry "swaync zou herstarten"
        return 0
    fi
    if pgrep -x swaync &>/dev/null; then
        pkill -x swaync || true
        sleep 0.3
        swaync &
        disown
        log_ok "SwayNC herstart"
    else
        log_info "SwayNC draait niet — wordt gestart bij volgende sessie via autostart"
    fi
}
