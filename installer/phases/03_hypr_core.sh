#!/usr/bin/env bash
# =============================================================================
# Fase 03 — Hyprland core
# =============================================================================
# Doel:
#   - Hyprland en kernpakketten installeren
#   - Modulaire conf.d-structuur deployen
#   - GTK-instellingen toepassen
#   - XDG-portalen configureren
#   - Sessie valideren (Hyprland start, workspaces werken)
# =============================================================================

phase_run() {
    log_step "Pakketten installeren voor Hyprland core..."
    _phase03_install_packages

    log_step "Hyprland config deployen..."
    _phase03_deploy_configs

    log_step "XDG-portalen configureren..."
    _phase03_configure_portals

    log_step "Fase 03 valideren..."
    _phase03_validate

    log_ok "Fase 03 voltooid — Hyprland core staat."
    log_info "Start een Hyprland-sessie via je login manager of 'Hyprland' in de terminal."
}

# ---------------------------------------------------------------------------

_phase03_install_packages() {
    install_from_manifest "$REPO_ROOT/manifest/packages/core.txt"

    # Extra kerntools die direct nodig zijn
    pacman_install \
        hyprlock \
        hypridle \
        hyprpaper \
        polkit-gnome \
        xdg-desktop-portal-hyprland \
        xdg-desktop-portal-gtk \
        wl-clipboard \
        cliphist \
        grim \
        slurp \
        swaync \
        playerctl
    aur_install satty
}

_phase03_deploy_configs() {
    # Hele hypr-map als symlink deployen
    deploy_config "hypr"

    # GTK-instellingen schrijven (niet via symlink, direct in home)
    _phase03_apply_gtk_settings
}

_phase03_apply_gtk_settings() {
    if "${DRY_RUN:-false}"; then
        log_dry "GTK-instellingen zouden worden toegepast"
        return 0
    fi

    local gtk3_dir="$HOME/.config/gtk-3.0"
    local gtk4_dir="$HOME/.config/gtk-4.0"
    local gtkrc="$HOME/.gtkrc-2.0"

    ensure_dir "$gtk3_dir"
    ensure_dir "$gtk4_dir"

    # GTK3 settings
    cat > "$gtk3_dir/settings.ini" <<'EOF'
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=adw-gtk3-dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Fira Sans 11
gtk-cursor-theme-name=Bibata-Modern-Classic
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_BOTH_HORIZ
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
EOF

    # GTK4 settings
    cat > "$gtk4_dir/settings.ini" <<'EOF'
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=adw-gtk3-dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Fira Sans 11
gtk-cursor-theme-name=Bibata-Modern-Classic
gtk-cursor-theme-size=24
EOF

    # GTK2 settings
    cat > "$gtkrc" <<'EOF'
gtk-theme-name="adw-gtk3-dark"
gtk-icon-theme-name="Papirus-Dark"
gtk-font-name="Fira Sans 11"
gtk-cursor-theme-name="Bibata-Modern-Classic"
gtk-cursor-theme-size=24
EOF

    log_ok "GTK-instellingen geschreven"
}

_phase03_configure_portals() {
    local portal_conf="$HOME/.config/xdg-desktop-portal/portals.conf"

    if "${DRY_RUN:-false}"; then
        log_dry "XDG-portalconfiguratie zou worden geschreven: $portal_conf"
        return 0
    fi

    ensure_dir "$(dirname "$portal_conf")"
    cat > "$portal_conf" <<'EOF'
[preferred]
default=hyprland;gtk
org.freedesktop.impl.portal.Screenshot=hyprland
org.freedesktop.impl.portal.ScreenCast=hyprland
org.freedesktop.impl.portal.FileChooser=gtk
org.freedesktop.impl.portal.Notification=gtk
EOF
    log_ok "XDG-portalconfiguratie geschreven"
}

_phase03_validate() {
    validate_cmd Hyprland
    validate_cmd hyprlock
    validate_cmd hypridle
    validate_cmd hyprpaper
    validate_cmd grim
    validate_cmd slurp
    validate_file "$HOME/.config/hypr/hyprland.conf" "~/.config/hypr/hyprland.conf"
    validate_dir  "$HOME/.config/hypr/conf.d"        "~/.config/hypr/conf.d/"
    validate_file "$HOME/.config/hypr/conf.d/30-general.conf"    "30-general.conf"
    validate_file "$HOME/.config/hypr/conf.d/70-autostart.conf"  "70-autostart.conf"
    validate_report
}
