#!/usr/bin/env bash
# =============================================================================
# Fase 13 — Monitoringlaag
# =============================================================================
# Doel:
#   - lm_sensors installeren (temperatuurbeheer)
#   - btop al geïnstalleerd in fase 2 — valideer
#   - sys_info.sh levert systeeemdata aan de topbar (CPU/RAM/netwerk/accu)
#   - sensors-detect uitvoeren voor temperatuurmapping
# =============================================================================

phase_run() {
    log_step "Monitoringpakketten installeren..."
    pacman_install lm_sensors       # temperatuursensoren (hwmon)
    if [[ "${DETECT_IS_LAPTOP:-false}" == "true" ]]; then
        _phase13_optional_pacman_install acpi "batterij/thermische info"
    else
        log_info "Geen laptop gedetecteerd — acpi CLI overgeslagen"
    fi

    log_step "lm_sensors initialiseren..."
    _phase13_sensors_detect

    log_step "Fase 13 valideren..."
    validate_cmd btop
    validate_cmd sensors
    validate_file "$HOME/.config/quickshell/sys_info.sh"     "sys_info.sh"
    validate_file "$HOME/.config/quickshell/TopBar.qml"      "TopBar.qml"
    validate_report

    log_ok "Fase 13 voltooid — Monitoringlaag actief."
    log_info "Systeemdata:   topbar toont CPU/RAM/netwerk/accu via sys_info.sh"
    log_info "Volledig:      btop in terminal"
}

# ---------------------------------------------------------------------------

_phase13_optional_pacman_install() {
    local pkg="$1"
    local label="$2"

    if pacman_install "$pkg"; then
        return 0
    fi

    log_warn "Optioneel pakket overgeslagen: $pkg ($label)"
    log_warn "Dit mag de installatie niet blokkeren; controleer later pacman/DNS/mirrors als je dit pakket wilt."
    return 0
}

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
