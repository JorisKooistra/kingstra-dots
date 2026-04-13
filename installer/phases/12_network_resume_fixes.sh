#!/usr/bin/env bash
# =============================================================================
# Fase 12 — Netwerk- en resume-fixes
# =============================================================================
# Doel:
#   - NetworkManager + nm-applet installeren (WiFi-wachtwoordprompts)
#   - Bluetooth-stack installeren (bluez + blueman)
#   - Resume-fix script deployen (WiFi/BT rescan, Quickshell/SwayNC herstel)
#   - kingstra-resume.service installeren als systemd-gebruikersservice
#   - kingstra-lid-lock.service installeren als systemd-gebruikersservice
#   - NetworkManager + bluetooth services activeren
# =============================================================================

phase_run() {
    log_step "Netwerkpakketten installeren..."
    pacman_install networkmanager
    pacman_install network-manager-applet   # nm-applet + nm-connection-editor
    pacman_install networkmanager-openvpn   # optionele VPN-ondersteuning

    log_step "Bluetooth-stack installeren..."
    pacman_install bluez
    pacman_install bluez-utils              # bluetoothctl CLI
    pacman_install blueman                  # GUI bluetooth-beheerder

    log_step "Resume-fix script deployen..."
    _phase12_deploy_resume_script

    log_step "Resume-service installeren..."
    _phase12_install_resume_service

    log_step "Lid-lock service installeren..."
    _phase12_install_lid_lock_service

    log_step "Systeemservices activeren..."
    _phase12_enable_services

    log_step "Fase 12 valideren..."
    validate_cmd nmcli
    validate_cmd nm-applet
    validate_cmd bluetoothctl
    validate_cmd blueman-manager
    validate_file "$HOME/.config/hypr/scripts/resume-fix.sh"           "resume-fix.sh"
    validate_file "$HOME/.config/hypr/scripts/lid-lock.sh"             "lid-lock.sh"
    validate_file "$HOME/.config/systemd/user/kingstra-resume.service" "kingstra-resume.service"
    validate_file "$HOME/.config/systemd/user/kingstra-lid-lock.service" "kingstra-lid-lock.service"
    validate_report

    log_ok "Fase 12 voltooid — Netwerk- en resume-fixes actief."
    log_info "WiFi beheren:   Super+Alt+N (nmtui in kitty)"
    log_info "Bluetooth:      Super+Alt+B (blueman)"
    log_info "Geavanceerd:    nm-connection-editor"
    log_info "Resume-service: systemctl --user status kingstra-resume"
    log_info "Lid-lock:       systemctl --user status kingstra-lid-lock"
}

# ---------------------------------------------------------------------------

_phase12_deploy_resume_script() {
    local script_src="$REPO_ROOT/config/hypr/scripts/resume-fix.sh"

    if "${DRY_RUN:-false}"; then
        log_dry "Resume-script wordt uitvoerbaar gemaakt: $script_src"
        return 0
    fi

    # Script zit al in config/hypr/scripts/ — symlink loopt via fase 3 deploy_config "hypr"
    if [[ -f "$script_src" ]]; then
        chmod +x "$script_src"
        log_ok "Resume-script uitvoerbaar: $script_src"
    else
        log_warn "Resume-script niet gevonden: $script_src"
    fi
}

_phase12_install_resume_service() {
    local service_src="$REPO_ROOT/config/systemd/kingstra-resume.service"
    local service_dest="$HOME/.config/systemd/user/kingstra-resume.service"

    if "${DRY_RUN:-false}"; then
        log_dry "Resume-service zou worden geïnstalleerd: $service_dest"
        return 0
    fi

    if [[ ! -f "$service_src" ]]; then
        log_warn "Service-bestand niet gevonden: $service_src"
        return 0
    fi

    ensure_dir "$HOME/.config/systemd/user"
    deploy_link "$service_src" "$service_dest"

    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable kingstra-resume.service 2>/dev/null && \
        log_ok "kingstra-resume.service ingeschakeld" || \
        log_warn "Service inschakelen mislukt — handmatig uitvoeren: systemctl --user enable kingstra-resume"
}

_phase12_install_lid_lock_service() {
    local service_src="$REPO_ROOT/config/systemd/kingstra-lid-lock.service"
    local service_dest="$HOME/.config/systemd/user/kingstra-lid-lock.service"
    local lid_script="$REPO_ROOT/config/hypr/scripts/lid-lock.sh"

    if "${DRY_RUN:-false}"; then
        log_dry "Lid-lock service zou worden geïnstalleerd: $service_dest"
        return 0
    fi

    if [[ ! -f "$service_src" ]]; then
        log_warn "Service-bestand niet gevonden: $service_src"
        return 0
    fi

    if [[ -f "$lid_script" ]]; then
        chmod +x "$lid_script"
    else
        log_warn "Lid-lock script niet gevonden: $lid_script"
    fi

    ensure_dir "$HOME/.config/systemd/user"
    deploy_link "$service_src" "$service_dest"

    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable --now kingstra-lid-lock.service 2>/dev/null && \
        log_ok "kingstra-lid-lock.service ingeschakeld en gestart" || \
        log_warn "Service inschakelen mislukt — handmatig uitvoeren: systemctl --user enable --now kingstra-lid-lock"
}

_phase12_enable_services() {
    if "${DRY_RUN:-false}"; then
        log_dry "Systeemservices zouden worden ingeschakeld (NetworkManager, bluetooth)"
        return 0
    fi

    # NetworkManager
    if ! systemctl is-enabled NetworkManager &>/dev/null; then
        sudo systemctl enable --now NetworkManager 2>/dev/null && \
            log_ok "NetworkManager ingeschakeld en gestart" || \
            log_warn "NetworkManager inschakelen mislukt"
    else
        log_info "NetworkManager al ingeschakeld"
        systemctl is-active NetworkManager &>/dev/null || \
            sudo systemctl start NetworkManager 2>/dev/null || true
    fi

    # Bluetooth
    if ! systemctl is-enabled bluetooth &>/dev/null; then
        sudo systemctl enable --now bluetooth 2>/dev/null && \
            log_ok "Bluetooth-service ingeschakeld en gestart" || \
            log_warn "Bluetooth inschakelen mislukt"
    else
        log_info "Bluetooth-service al ingeschakeld"
    fi

    # wpa_supplicant — standaard backend voor NetworkManager
    if ! systemctl is-enabled wpa_supplicant &>/dev/null; then
        sudo systemctl enable wpa_supplicant 2>/dev/null || true
    fi
}
