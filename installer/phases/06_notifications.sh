#!/usr/bin/env bash
# =============================================================================
# Fase 06 — Quickshell notificaties
# =============================================================================

phase_run() {
    log_step "Legacy SwayNC stoppen als die actief is..."
    _phase06_stop_swaync

    log_step "Fase 06 valideren..."
    validate_cmd quickshell
    validate_file "$HOME/.config/quickshell/NotificationService.qml"                 "quickshell/NotificationService.qml"
    validate_file "$HOME/.config/quickshell/notifications/NotificationPopup.qml"     "quickshell/notifications/NotificationPopup.qml"
    validate_file "$HOME/.config/quickshell/notifications/notification_control.sh"   "quickshell/notifications/notification_control.sh"
    validate_report

    log_ok "Fase 06 voltooid — Quickshell-notificaties staan."
}

_phase06_stop_swaync() {
    if "${DRY_RUN:-false}"; then
        log_dry "swaync zou worden gestopt"
        return 0
    fi
    if pgrep -x swaync &>/dev/null; then
        pkill -x swaync || true
        log_ok "SwayNC gestopt"
    else
        log_info "SwayNC draait niet"
    fi
}
