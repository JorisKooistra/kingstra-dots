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

    log_step "WiFi/Bluetooth-stabiliteitstweaks deployen..."
    _phase12_deploy_wireless_tweaks

    log_step "Resume-fix script deployen..."
    _phase12_deploy_resume_script

    log_step "Resume-service installeren..."
    _phase12_install_resume_service

    log_step "Lid-lock service installeren..."
    _phase12_install_lid_lock_service

    log_step "Systeemservices activeren..."
    _phase12_enable_services

    log_step "Koppeling met je andere machine (muis, toetsenbord, klembord)..."
    _phase12_koppeling

    log_step "Fase 12 valideren..."
    validate_cmd nmcli
    validate_cmd nm-applet
    validate_cmd bluetoothctl
    validate_cmd blueman-manager
    validate_file "$HOME/.config/hypr/scripts/resume-fix.sh"           "resume-fix.sh"
    validate_file "$HOME/.config/hypr/scripts/lid-lock.sh"             "lid-lock.sh"
    validate_file "$HOME/.config/systemd/user/kingstra-resume.service" "kingstra-resume.service"
    validate_file "$HOME/.config/systemd/user/kingstra-lid-lock.service" "kingstra-lid-lock.service"
    validate_file "$HOME/.local/bin/kingstra-koppel" "kingstra-koppel"
    validate_report

    log_ok "Fase 12 voltooid — Netwerk- en resume-fixes actief."
    log_info "WiFi beheren:   nmtui (toetsenbordmenu › Snel schakelen)"
    log_info "Bluetooth:      Blueman (toetsenbordmenu › Snel schakelen)"
    log_info "Geavanceerd:    nm-connection-editor"
    log_info "Resume-service: systemctl --user status kingstra-resume"
    log_info "Lid-lock:       systemctl --user status kingstra-lid-lock"
}

# ---------------------------------------------------------------------------

_phase12_deploy_wireless_tweaks() {
    local nm_src="$REPO_ROOT/config/system/networkmanager-wifi.conf"
    local nm_dest="/etc/NetworkManager/conf.d/99-kingstra-wifi.conf"
    local modprobe_src="$REPO_ROOT/config/system/modprobe-wireless.conf"
    local modprobe_dest="/etc/modprobe.d/99-kingstra-wireless.conf"
    local sleep_src="$REPO_ROOT/config/system/system-sleep-wireless.sh"
    local sleep_dest="/usr/lib/systemd/system-sleep/kingstra-wireless"

    if "${DRY_RUN:-false}"; then
        log_dry "WiFi/BT-tweaks zouden worden geplaatst: $nm_dest, $modprobe_dest, $sleep_dest (vereist sudo)"
        return 0
    fi

    if [[ -f "$nm_src" ]]; then
        backup_system_path "$nm_dest"
        sudo mkdir -p /etc/NetworkManager/conf.d
        sudo cp "$nm_src" "$nm_dest"
        log_ok "NetworkManager WiFi-powersave uit: $nm_dest"
    else
        log_warn "Bron niet gevonden: $nm_src"
    fi

    if [[ -f "$modprobe_src" ]]; then
        backup_system_path "$modprobe_dest"
        sudo mkdir -p /etc/modprobe.d
        sudo cp "$modprobe_src" "$modprobe_dest"
        log_ok "Kernelmodule-opties geplaatst: $modprobe_dest (actief na reboot)"
    else
        log_warn "Bron niet gevonden: $modprobe_src"
    fi

    if [[ -f "$sleep_src" ]]; then
        backup_system_path "$sleep_dest"
        sudo mkdir -p /usr/lib/systemd/system-sleep
        sudo install -m 0755 "$sleep_src" "$sleep_dest"
        log_ok "System-sleep hook geplaatst: $sleep_dest"
    else
        log_warn "Bron niet gevonden: $sleep_src"
    fi

    # Direct toepassen op de draaiende sessie (reboot niet nodig voor NM)
    sudo systemctl reload NetworkManager 2>/dev/null || true
}

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

    # Deze user-service wordt expliciet gestart vanuit resume-display.sh.
    # User-managers ontvangen de system-suspend.target niet betrouwbaar.
    systemctl --user disable kingstra-resume.service 2>/dev/null || true
    deploy_link "$service_src" "$service_dest"
    systemctl --user daemon-reload 2>/dev/null || true
    log_ok "kingstra-resume.service geïnstalleerd (gestart door resume-display.sh)"
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

    _phase12_single_dhcp_client

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

# NetworkManager én systemd-networkd tegelijk = twee DHCP-clients op dezelfde
# interface en dus twee IP-adressen. Welk adres "primair" wordt verschilt per
# boot; lan-mouse (kingstra koppel) antwoordt dan vanaf een ander adres dan
# waar de andere machine naartoe stuurt en muis delen werkt niet meer.
# Alleen als NetworkManager enabled én actief is: networkd uitschakelen.
_phase12_single_dhcp_client() {
    [[ "$(systemctl is-enabled NetworkManager 2>/dev/null)" == enabled ]] || return 0
    systemctl is-active --quiet NetworkManager || return 0
    [[ "$(systemctl is-enabled systemd-networkd.service 2>/dev/null)" == enabled ]] || return 0

    log_warn "NetworkManager en systemd-networkd draaien allebei: twee DHCP-clients, twee IP-adressen"
    local units=(systemd-networkd.service systemd-networkd.socket) u
    [[ "$(systemctl is-enabled systemd-networkd-wait-online.service 2>/dev/null)" == enabled ]] \
        && units+=(systemd-networkd-wait-online.service)
    for u in "${units[@]}"; do
        sudo systemctl disable --now "$u" 2>/dev/null || true
    done
    if [[ "$(systemctl is-enabled systemd-networkd.service 2>/dev/null)" == enabled ]]; then
        log_warn "systemd-networkd uitschakelen mislukt — handmatig: sudo systemctl disable --now ${units[*]}"
    else
        log_ok "systemd-networkd uitgeschakeld; NetworkManager is nu de enige DHCP-client"
    fi
}

# ---------------------------------------------------------------------------
# kingstra koppel: pc en laptop aan elkaar koppelen. Hier alleen klaarzetten
# (pakketten, ssh-server, script en diensten); het koppelen zelf doe je één
# keer met `kingstra koppel <machine> [links|rechts]`. De diensten starten pas
# als ~/.config/kingstra/koppeling.json bestaat (kingstra-session-start).
_phase12_koppeling() {
    pacman_install_optional lan-mouse
    pacman_install_optional openssh

    if "${DRY_RUN:-false}"; then
        log_dry "kingstra-koppel, kingstra-lan-mouse.service en kingstra-klembord.service zouden worden geplaatst; sshd aan"
        return 0
    fi

    local src="$REPO_ROOT/config/shared/scripts/kingstra-koppel" unit
    ensure_dir "$HOME/.local/bin"
    chmod +x "$src"
    deploy_link "$src" "$HOME/.local/bin/kingstra-koppel"

    ensure_dir "$HOME/.config/systemd/user"
    for unit in kingstra-lan-mouse.service kingstra-klembord.service kingstra-koppel-ip.service kingstra-koppel-ip.timer; do
        deploy_link "$REPO_ROOT/config/systemd/$unit" "$HOME/.config/systemd/user/$unit"
    done
    systemctl --user daemon-reload 2>/dev/null || true

    # De andere machine komt via ssh binnen (klembord, bestanden, koppelen).
    # Thuis achter de router; root mag niet inloggen (Arch-standaard).
    if systemctl list-unit-files sshd.service &>/dev/null; then
        if [[ "$(systemctl is-enabled sshd 2>/dev/null)" != "enabled" ]]; then
            sudo systemctl enable --now sshd 2>/dev/null \
                && log_ok "ssh-server aan (voor kingstra koppel)" \
                || log_warn "ssh-server aanzetten mislukt"
        fi
    fi

    if [[ -f "$HOME/.config/kingstra/koppeling.json" ]]; then
        systemctl --user restart kingstra-lan-mouse.service kingstra-klembord.service kingstra-koppel-ip.timer 2>/dev/null || true
        log_ok "Koppeling actief ($(python3 -c 'import json;print(json.load(open("'"$HOME"'/.config/kingstra/koppeling.json")).get("host","?"))' 2>/dev/null))"
    else
        log_info "Koppelen met je andere machine: kingstra koppel <naam> [links|rechts]"
    fi
}
