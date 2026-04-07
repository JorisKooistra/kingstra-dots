#!/usr/bin/env bash
# =============================================================================
# Fase 13 — Monitoringlaag
# =============================================================================
# Doel:
#   - lm_sensors installeren (temperatuurbeheer)
#   - btop al geïnstalleerd in fase 2 — valideer
#   - StatsPopup al in config/quickshell (klik op SystemStats-pill)
#   - sensors-detect uitvoeren voor temperatuurmapping
#   - IPC-toegang tot stats popup valideren
# =============================================================================

phase_run() {
    log_step "Monitoringpakketten installeren..."
    pacman_install lm_sensors       # temperatuursensoren (hwmon)
    pacman_install acpi             # batterij/thermisch info (laptop)
    pacman_install nvtop            # GPU monitor (nvidia/amd/intel)
    pacman_install htop             # lichtgewicht procesmontior

    log_step "lm_sensors initialiseren..."
    _phase13_sensors_detect

    log_step "Quickshell StatsPopup valideren..."
    _phase13_validate_statspopup

    log_step "Fase 13 valideren..."
    validate_cmd btop
    validate_cmd lm_sensors || validate_cmd sensors
    validate_file "$HOME/.config/quickshell/bar/popups/StatsPopup.qml" "StatsPopup.qml"
    validate_file "$HOME/.config/quickshell/bar/modules/SystemStats.qml" "SystemStats.qml"
    validate_report

    log_ok "Fase 13 voltooid — Monitoringlaag actief."
    log_info "Stats-popup:   klik op de CPU/RAM-pill in de topbar"
    log_info "Volledig:      Super+Shift+Return (btop in kitty)"
    log_info "IPC toggle:    qs ipc call stats toggle"
}

# ---------------------------------------------------------------------------

_phase13_sensors_detect() {
    if "${DRY_RUN:-false}"; then
        log_dry "sensors-detect zou worden uitgevoerd (automatische modus)"
        return 0
    fi

    if ! command -v sensors &>/dev/null; then
        log_warn "lm_sensors niet gevonden — sensors-detect overgeslagen"
        return 0
    fi

    # Controleer of sensors al geconfigureerd zijn
    if [[ -f /etc/sensors3.conf ]] || [[ -d /etc/sensors.d ]]; then
        log_info "lm_sensors al geconfigureerd — sensors-detect overgeslagen"
        return 0
    fi

    log_info "sensors-detect uitvoeren in automatische modus (geen interactie)..."
    sudo sensors-detect --auto 2>/dev/null && \
        log_ok "sensors-detect voltooid" || \
        log_warn "sensors-detect mislukt — temperatuur wordt gelezen via /sys/class/thermal (kernel)"

    # Laad modules
    sudo systemctl enable --now lm_sensors 2>/dev/null || true
}

_phase13_validate_statspopup() {
    local popup_file="$REPO_ROOT/config/quickshell/bar/popups/StatsPopup.qml"

    if [[ ! -f "$popup_file" ]]; then
        log_warn "StatsPopup.qml niet gevonden in repo: $popup_file"
        return 0
    fi

    log_ok "StatsPopup.qml aanwezig in repo"
    log_info "  Popup wordt geladen via deploy_config 'quickshell' (fase 5)"
}
