#!/usr/bin/env bash
# =============================================================================
# Fase 11 — Apps en dagelijkse tools
# =============================================================================
# Doel:
#   - Dagelijkse apps installeren (nautilus, cliphist, playerctl, screenshot-tools)
#   - Yazi bestandsbeheerder + config deployen
#   - Optionele apps op basis van profielvlaggen (Spicetify, Vesktop)
#   - Polkit-agent + authenticatielaag valideren
#   - Screenshot-toolchain valideren (grim + slurp + satty + wl-clipboard)
# =============================================================================

phase_run() {
    log_step "Bestandsbeheerder installeren..."
    pacman_install nautilus
    pacman_install file-roller          # archiefbeheer in Nautilus
    pacman_install gvfs                 # trash/MTP/samba support
    pacman_install gvfs-mtp             # MTP (telefoons via USB)

    log_step "Klembord installeren..."
    pacman_install cliphist
    pacman_install wl-clipboard         # wl-copy / wl-paste
    pacman_install wtype                # fallback voor automatisch plakken na cliphist

    log_step "Media-tools installeren..."
    pacman_install playerctl
    pacman_install mpv                  # videospeler (ook voor yazi preview)

    log_step "Screenshot-toolchain installeren..."
    pacman_install grim
    pacman_install slurp
    aur_install satty

    log_step "Authenticatieagent installeren..."
    pacman_install polkit-gnome

    log_step "Netwerkbeheer GUI installeren..."
    pacman_install network-manager-applet
    pacman_install blueman

    log_step "Yazi bestandsbeheerder installeren..."
    pacman_install yazi
    pacman_install p7zip                # uitpakken vanuit yazi (7z, xz, bzip2...)
    pacman_install unzip zip            # zip-bestanden vanuit yazi

    log_step "Yazi-config deployen..."
    deploy_config "yazi"
    _phase11_init_yazi_theme_file

    log_step "Optionele apps installeren..."
    _phase11_optional_apps

    log_step "Fase 11 valideren..."
    validate_cmd nautilus
    validate_cmd cliphist
    validate_cmd wl-copy
    validate_cmd wtype
    validate_cmd playerctl
    validate_cmd grim
    validate_cmd slurp
    validate_cmd yazi
    validate_file "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1" "polkit-gnome"
    validate_dir  "$HOME/.config/yazi" "yazi config"
    validate_file "$HOME/.config/yazi/yazi.toml"    "yazi.toml"
    validate_file "$HOME/.config/yazi/keymap.toml"  "yazi keymap.toml"
    validate_file "$HOME/.config/yazi/theme.toml"   "yazi theme.toml"
    validate_report

    log_ok "Fase 11 voltooid — Apps en dagelijkse tools beschikbaar."
    log_info "Bestandsbeheer:  yazi (Super+E opent nautilus, Super+Shift+E start yazi)"
    log_info "Klembord:        Super+V — cliphist via Walker, plakt selectie"
    log_info "Screenshot:      Print / Super+Print / Shift+Print"
}

# ---------------------------------------------------------------------------

_phase11_optional_apps() {
    # Office-suite (gevraagd als "OpenOffice"; op Arch gebruiken we LibreOffice)
    if [[ "${ENABLE_OPTIONAL_OFFICE:-false}" == "true" ]]; then
        log_info "Office-suite installeren (ENABLE_OPTIONAL_OFFICE=true)..."
        pacman_install libreoffice-fresh
    else
        log_info "Office-suite overgeslagen (ENABLE_OPTIONAL_OFFICE=false)"
    fi

    # Heroic Games Launcher
    if [[ "${ENABLE_OPTIONAL_HEROIC:-false}" == "true" ]]; then
        log_info "Heroic Games Launcher installeren (ENABLE_OPTIONAL_HEROIC=true)..."
        aur_install heroic-games-launcher-bin
    else
        log_info "Heroic Games Launcher overgeslagen (ENABLE_OPTIONAL_HEROIC=false)"
    fi

    # VLC mediaspeler
    if [[ "${ENABLE_OPTIONAL_VLC:-false}" == "true" ]]; then
        log_info "VLC installeren (ENABLE_OPTIONAL_VLC=true)..."
        pacman_install vlc
    else
        log_info "VLC overgeslagen (ENABLE_OPTIONAL_VLC=false)"
    fi

    # Spicetify (Spotify-theming)
    if [[ "${ENABLE_SPICETIFY:-false}" == "true" ]]; then
        log_info "Spicetify installeren (ENABLE_SPICETIFY=true)..."
        aur_install spicetify-cli
        _phase11_setup_spicetify
    else
        log_info "Spicetify overgeslagen (ENABLE_SPICETIFY=false)"
    fi

    # Vesktop (Discord-client met RPC + screenshare)
    if [[ "${ENABLE_VESKTOP:-false}" == "true" ]]; then
        log_info "Vesktop installeren (ENABLE_VESKTOP=true)..."
        aur_install vesktop-bin
    else
        log_info "Vesktop overgeslagen (ENABLE_VESKTOP=false)"
    fi

    # VSCode — altijd nuttig maar optioneel
    if pacman -Qq visual-studio-code-bin &>/dev/null 2>&1 || \
       pacman -Qq code &>/dev/null 2>&1; then
        log_info "VSCode al geïnstalleerd — overgeslagen"
    else
        log_info "VSCode niet geïnstalleerd. Installeren via: aur_install visual-studio-code-bin"
        log_info "Of via pacman: pacman -S code (open-source build)"
    fi
}

_phase11_init_yazi_theme_file() {
    local yazi_theme="$HOME/.config/yazi/theme.toml"

    if "${DRY_RUN:-false}"; then
        log_dry "Yazi theme placeholder zou worden aangemaakt: $yazi_theme"
        return 0
    fi

    if [[ -f "$yazi_theme" || -L "$yazi_theme" ]]; then
        return 0
    fi

    cat > "$yazi_theme" <<'EOF'
# Runtime placeholder for Yazi theme.
# This file is generated/updated by Matugen integration.
EOF
    log_ok "Yazi theme placeholder aangemaakt: $yazi_theme"
}

_phase11_setup_spicetify() {
    if "${DRY_RUN:-false}"; then
        log_dry "Spicetify setup zou worden uitgevoerd"
        return 0
    fi

    if ! command -v spicetify &>/dev/null; then
        log_warn "spicetify niet gevonden — setup overgeslagen"
        return 0
    fi

    # Geef Spicetify schrijftoegang tot de Spotify-map
    if [[ -d /opt/spotify ]]; then
        sudo chmod a+wr /opt/spotify
        sudo chmod a+wr /opt/spotify/Apps -R
        log_ok "Spotify schrijfrechten ingesteld voor Spicetify"
    fi

    spicetify backup apply 2>/dev/null || \
        log_warn "Spicetify backup/apply mislukt — start Spotify eerst om te initialiseren"
}
