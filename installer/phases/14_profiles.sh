#!/usr/bin/env bash
# =============================================================================
# Fase 14 — Hardware-aanpassing (vroeger: profielen)
# =============================================================================
# Doel:
#   - 72-hardware.conf genereren op basis van gedetecteerde hardware
#     (GPU env vars, touchpad/tablet-instellingen)
#   - Optionele pakketten installeren op basis van detectie
#     (power-profiles-daemon, fprintd, brightnessctl)
#   - Laptop/tablet-specifieke tweaks toepassen
#   - Nvidia: hyprland nvidia-pakketten + render fixes
# =============================================================================

phase_run() {
    log_step "Hardware-config genereren (72-hardware.conf)..."
    _phase14_write_hardware_conf

    log_step "GPU-specifieke aanpassingen..."
    _phase14_gpu_setup

    log_step "Laptop-features installeren (indien gedetecteerd)..."
    _phase14_laptop_features

    log_step "Tablet-mode features installeren (indien gedetecteerd)..."
    _phase14_tablet_mode_features

    log_step "Vingerafdruk configureren (indien gedetecteerd)..."
    _phase14_fingerprint_setup

    log_step "Fase 14 valideren..."
    validate_file "$HOME/.config/hypr/conf.d/72-hardware.conf" "72-hardware.conf"
    validate_report

    log_ok "Fase 14 voltooid — Hardware-aanpassingen toegepast."
    _phase14_print_summary
}

# ---------------------------------------------------------------------------

_phase14_write_hardware_conf() {
    local dest="$HOME/.config/hypr/conf.d/72-hardware.conf"

    if "${DRY_RUN:-false}"; then
        log_dry "72-hardware.conf zou worden gegenereerd"
        log_dry "  GPU:     ${DETECT_GPU:-unknown}"
        log_dry "  Laptop:  ${DETECT_IS_LAPTOP:-false}"
        log_dry "  Touchpad:${DETECT_HAS_TOUCHPAD:-false}"
        log_dry "  Touch:   ${DETECT_HAS_TOUCHSCREEN:-false}"
        log_dry "  Tablet:  ${ENABLE_TABLET_MODE:-false}"
        return 0
    fi

    ensure_dir "$(dirname "$dest")"

    # Bouw de config op
    {
        echo "# ============================================================================="
        echo "# 72-hardware.conf — Automatisch gegenereerd door fase 14"
        echo "# Gegenereerd op: $(date '+%Y-%m-%d %H:%M')"
        echo "# GPU: ${DETECT_GPU:-unknown} | Laptop: ${DETECT_IS_LAPTOP:-false} | Touchpad: ${DETECT_HAS_TOUCHPAD:-false} | Touchscreen: ${DETECT_HAS_TOUCHSCREEN:-false} | Tablet mode: ${ENABLE_TABLET_MODE:-false}"
        echo "# ============================================================================="
        echo ""

        # GPU-omgevingsvariabelen
        case "${DETECT_GPU:-unknown}" in
            nvidia)
                echo "# ---------------------------------------------------------------------------"
                echo "# Nvidia GPU — vereiste omgevingsvariabelen"
                echo "# ---------------------------------------------------------------------------"
                echo "env = LIBVA_DRIVER_NAME,nvidia"
                echo "env = __GLX_VENDOR_LIBRARY_NAME,nvidia"
                echo "env = NVD_BACKEND,direct"
                echo "env = GBM_BACKEND,nvidia-drm"
                echo "env = __NV_PRIME_RENDER_OFFLOAD,1"
                echo "env = WLR_NO_HARDWARE_CURSORS,1"
                echo ""
                echo "# Nvidia cursor fix"
                echo "cursor {"
                echo "    no_hardware_cursors = true"
                echo "}"
                echo ""
                ;;
            amd)
                echo "# ---------------------------------------------------------------------------"
                echo "# AMD GPU — VA-API driver"
                echo "# ---------------------------------------------------------------------------"
                echo "env = LIBVA_DRIVER_NAME,radeonsi"
                echo ""
                ;;
            intel)
                echo "# ---------------------------------------------------------------------------"
                echo "# Intel GPU — VA-API driver"
                echo "# ---------------------------------------------------------------------------"
                echo "env = LIBVA_DRIVER_NAME,iHD"
                echo ""
                ;;
            *)
                echo "# Geen specifieke GPU-env vars nodig"
                echo ""
                ;;
        esac

        # Touchpad
        if [[ "${DETECT_HAS_TOUCHPAD:-false}" == "true" ]]; then
            local natural="${TOUCHPAD_NATURAL_SCROLL:-true}"
            echo "# ---------------------------------------------------------------------------"
            echo "# Touchpad-instellingen (laptop)"
            echo "# ---------------------------------------------------------------------------"
            echo "input {"
            echo "    touchpad {"
            echo "        natural_scroll = $natural"
            echo "        scroll_factor = 0.8"
            echo "        tap-to-click = true"
            echo "        tap-and-drag = true"
            echo "        disable_while_typing = true"
            echo "        drag_lock = false"
            echo "    }"
            echo "}"
            echo ""
        fi

        # Laptop: extra animatie-snelheid (batterijbesparing)
        if [[ "${DETECT_IS_LAPTOP:-false}" == "true" ]]; then
            echo "# ---------------------------------------------------------------------------"
            echo "# Laptop — lichtere decoraties (batterijbesparing)"
            echo "# ---------------------------------------------------------------------------"
            echo "decoration {"
            echo "    blur {"
            echo "        passes = 2"
            echo "        size   = 6"
            echo "    }"
            echo "}"
            echo ""
        fi

        if [[ "${ENABLE_TABLET_MODE:-false}" == "true" ]]; then
            echo "# ---------------------------------------------------------------------------"
            echo "# Tablet mode — 2-in-1 / touchscreen laptop"
            echo "# ---------------------------------------------------------------------------"
            echo "# Automatisch via de hardware tablet-mode switch. De extra keybind is een"
            echo "# fallback voor touch-laptops die geen switch-event aan Hyprland doorgeven."
            echo "bindl = , switch:on:Tablet Mode Switch, exec, ~/.config/hypr/scripts/tablet-mode.sh on"
            echo "bindl = , switch:off:Tablet Mode Switch, exec, ~/.config/hypr/scripts/tablet-mode.sh off"
            echo "bindl = , switch:on:Tablet Mode, exec, ~/.config/hypr/scripts/tablet-mode.sh on"
            echo "bindl = , switch:off:Tablet Mode, exec, ~/.config/hypr/scripts/tablet-mode.sh off"
            echo "bindl = , switch:on:Intel HID switches, exec, ~/.config/hypr/scripts/tablet-mode.sh toggle"
            echo "bindl = , switch:off:Intel HID switches, exec, ~/.config/hypr/scripts/tablet-mode.sh off"
            echo "bind = \$mainMod CTRL, F12, exec, ~/.config/hypr/scripts/tablet-mode.sh toggle"
            echo ""
        fi

    } > "$dest"

    log_ok "72-hardware.conf gegenereerd: $dest"
}

_phase14_gpu_setup() {
    case "${DETECT_GPU:-unknown}" in
        nvidia)
            log_info "Nvidia GPU gedetecteerd — extra pakketten installeren"
            if "${DRY_RUN:-false}"; then
                log_dry "nvidia-dkms, nvidia-utils, libva-nvidia-driver zouden worden geïnstalleerd"
                return 0
            fi
            pacman_install nvidia-utils
            pacman_install libva-nvidia-driver 2>/dev/null || \
                log_warn "libva-nvidia-driver niet beschikbaar in repo — installeer handmatig of via AUR"
            ;;
        amd)
            log_info "AMD GPU gedetecteerd"
            pacman_install mesa
            pacman_install vulkan-radeon 2>/dev/null || true
            ;;
        intel)
            log_info "Intel GPU gedetecteerd"
            pacman_install mesa
            pacman_install intel-media-driver 2>/dev/null || true
            ;;
        *)
            log_info "GPU-type onbekend — geen extra pakketten geïnstalleerd"
            ;;
    esac
}

_phase14_laptop_features() {
    if [[ "${DETECT_IS_LAPTOP:-false}" != "true" ]]; then
        log_info "Geen laptop gedetecteerd — laptop-features overgeslagen"
        return 0
    fi

    log_info "Laptop gedetecteerd — extra features installeren"

    # Power profiles daemon
    if [[ "${ENABLE_POWER_PROFILES:-false}" == "true" ]]; then
        pacman_install power-profiles-daemon
        if ! "${DRY_RUN:-false}"; then
            sudo systemctl enable --now power-profiles-daemon 2>/dev/null && \
                log_ok "power-profiles-daemon geactiveerd" || \
                log_warn "power-profiles-daemon activeren mislukt"
        fi
    fi

    # Helderheidsregeling
    if [[ "${ENABLE_BRIGHTNESS_CONTROL:-false}" == "true" ]]; then
        pacman_install brightnessctl
        if ! "${DRY_RUN:-false}"; then
            # Geef gebruiker schrijftoegang zonder sudo
            sudo usermod -aG video "$USER" 2>/dev/null && \
                log_ok "Gebruiker toegevoegd aan groep 'video' (brightnessctl)" || true
        fi
    fi

    # Acpi events
    pacman_install acpid
    if ! "${DRY_RUN:-false}"; then
        sudo systemctl enable --now acpid 2>/dev/null || true
    fi
}

_phase14_tablet_mode_features() {
    local tablet_script="$REPO_ROOT/config/hypr/scripts/tablet-mode.sh"

    if [[ "${ENABLE_TABLET_MODE:-false}" != "true" ]]; then
        log_info "Tablet-mode niet gedetecteerd — overgeslagen"
        return 0
    fi

    log_info "Tablet-mode gedetecteerd — OSK en tablet-helper installeren"

    if "${DRY_RUN:-false}"; then
        log_dry "wvkbd zou worden geïnstalleerd en tablet-mode.sh uitvoerbaar gemaakt"
        return 0
    fi

    if [[ -f "$tablet_script" ]]; then
        chmod +x "$tablet_script"
        log_ok "Tablet-mode script uitvoerbaar: $tablet_script"
    else
        log_warn "Tablet-mode script niet gevonden: $tablet_script"
    fi

    if pacman_install wvkbd; then
        log_ok "On-screen keyboard geïnstalleerd: wvkbd"
    elif aur_install wvkbd; then
        log_ok "On-screen keyboard geïnstalleerd via AUR: wvkbd"
    else
        log_warn "wvkbd installeren mislukt — tablet-mode werkt, maar zonder automatisch schermtoetsenbord"
    fi
}

_phase14_fingerprint_setup() {
    if [[ "${DETECT_HAS_FINGERPRINT:-false}" != "true" ]]; then
        log_info "Geen vingerafdrukscanner gedetecteerd — overgeslagen"
        return 0
    fi

    if [[ "${ENABLE_FINGERPRINT:-false}" != "true" ]]; then
        log_info "ENABLE_FINGERPRINT=false — vingerafdruk overgeslagen"
        return 0
    fi

    log_info "Vingerafdrukscanner gedetecteerd — fprintd installeren"
    pacman_install fprintd
    pacman_install imagemagick    # voor fprintd-enroll visualisatie

    if "${DRY_RUN:-false}"; then
        log_dry "PAM-configuratie zou worden bijgewerkt voor fprintd"
        return 0
    fi

    # PAM configureren voor sudo + SDDM + hyprlock
    _phase14_pam_enable_fprintd "/etc/pam.d/sudo" "sudo"
    _phase14_pam_enable_fprintd "/etc/pam.d/sddm" "sddm" "max-tries=1 timeout=7"
    _phase14_pam_enable_fprintd "/etc/pam.d/hyprlock" "hyprlock" "max-tries=1 timeout=7"

    log_info "Vingerafdruk inschrijven: fprintd-enroll (na installatie uitvoeren)"
}

_phase14_pam_enable_fprintd() {
    local pam_file="$1"
    local label="$2"
    local pam_opts="${3:-}"
    local pam_line="auth       sufficient   pam_fprintd.so"
    [[ -n "$pam_opts" ]] && pam_line="$pam_line $pam_opts"

    if [[ ! -f "$pam_file" ]]; then
        log_warn "PAM-bestand ontbreekt: $pam_file ($label)"
        return 0
    fi

    # Ensure exactly one pam_fprintd auth line, then place it at the top.
    if sudo sed -i -E '/^[[:space:]]*auth[[:space:]]+.*pam_fprintd\.so([[:space:]].*)?$/d' "$pam_file" 2>/dev/null && \
       sudo sed -i "1i $pam_line" "$pam_file" 2>/dev/null; then
        log_ok "fprintd PAM-entry toegevoegd aan $pam_file"
    else
        log_warn "PAM aanpassen mislukt voor $pam_file — handmatig toevoegen"
    fi
}

_phase14_print_summary() {
    log_info "─── Toegepaste hardware-aanpassingen ──────────────"
    log_info " GPU-config:   ${DETECT_GPU:-unknown}"
    log_info " Touchpad:     ${DETECT_HAS_TOUCHPAD:-false}"
    log_info " Touchscreen:  ${DETECT_HAS_TOUCHSCREEN:-false}"
    log_info " Tablet mode:  ${ENABLE_TABLET_MODE:-false}"
    log_info " Power profs:  ${ENABLE_POWER_PROFILES:-false}"
    log_info " Brightness:   ${ENABLE_BRIGHTNESS_CONTROL:-false}"
    log_info " Fingerprint:  ${ENABLE_FINGERPRINT:-false}"
    log_info " Config:       ~/.config/hypr/conf.d/72-hardware.conf"
    log_info "───────────────────────────────────────────────────"
    log_info "Override-flags instellen: ./install.sh --override mijn-overrides.conf"
}
