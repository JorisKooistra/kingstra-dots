#!/usr/bin/env bash
# =============================================================================
# Fase 03 — Hyprland core
# =============================================================================
# Doel:
#   - Hyprland en kernpakketten installeren
#   - Modulaire Lua-configuratie deployen
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
    _phase03_configure_share_picker

    log_step "Papierformaat A4 instellen..."
    _phase03_configure_paper

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
        polkit-gnome \
        xdg-desktop-portal-hyprland \
        xdg-desktop-portal-gtk \
        xdg-desktop-portal-gnome \
        wl-clipboard \
        cliphist \
        wtype \
        grim \
        slurp \
        playerctl \
        hyprsunset
    aur_install_optional satty
}

_phase03_deploy_configs() {
    # Hele hypr-map als symlink deployen
    deploy_config "hypr"

    # User-state bestanden initialiseren vanuit .default templates
    deploy_defaults "$REPO_ROOT/config/hypr"

    # Git bewaart executable bits, maar expliciet zetten voorkomt stille regressies
    # na handmatige kopieën of filesystems die modebits verliezen.
    _phase03_prepare_hypr_scripts
    _phase03_deploy_session_entrypoint

    # GTK-instellingen schrijven (niet via symlink, direct in home)
    _phase03_apply_gtk_settings
}

_phase03_prepare_hypr_scripts() {
    local -a scripts=(
        "$REPO_ROOT/config/hypr/scripts/fingerprint-first-run.sh"
        "$REPO_ROOT/config/hypr/scripts/hardware-switches.sh"
        "$REPO_ROOT/config/hypr/scripts/hypr-dispatch.sh"
        "$REPO_ROOT/config/hypr/scripts/lid-lock.sh"
        "$REPO_ROOT/config/hypr/scripts/monitor-hotplug-restore.sh"
        "$REPO_ROOT/config/hypr/scripts/monitor-apply-save.sh"
        "$REPO_ROOT/config/hypr/scripts/workspace-monitor-assignments.sh"
        "$REPO_ROOT/config/hypr/scripts/workspace-scroll-monitor.sh"
        "$REPO_ROOT/config/hypr/scripts/tablet-mode.sh"
    )

    if "${DRY_RUN:-false}"; then
        log_dry "Hypr helper-scripts zouden uitvoerbaar worden gemaakt"
        return 0
    fi

    local script
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            chmod +x "$script"
            log_ok "Hypr helper-script uitvoerbaar: $script"
        else
            log_warn "Hypr helper-script niet gevonden: $script"
        fi
    done
}

_phase03_deploy_session_entrypoint() {
    local script_src="$REPO_ROOT/config/shared/scripts/kingstra-session-start"
    local script_dest="$HOME/.local/bin/kingstra-session-start"

    if "${DRY_RUN:-false}"; then
        log_dry "Sessie-entrypoint zou worden gedeployed: $script_dest"
        return 0
    fi

    ensure_dir "$HOME/.local/bin"
    deploy_link "$script_src" "$script_dest"
    chmod +x "$script_src"
    log_ok "Sessie-entrypoint beschikbaar als: kingstra-session-start"
}

_phase03_apply_gtk_settings() {
    if "${DRY_RUN:-false}"; then
        log_dry "GTK-instellingen zouden worden toegepast"
        return 0
    fi

    local gtk3_dir="$HOME/.config/gtk-3.0"
    local gtk4_dir="$HOME/.config/gtk-4.0"
    local gtkrc="$HOME/.gtkrc-2.0"

    backup_path "$gtk3_dir/settings.ini"
    backup_path "$gtk4_dir/settings.ini"
    backup_path "$gtkrc"

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

    backup_path "$portal_conf"
    ensure_dir "$(dirname "$portal_conf")"
    cat > "$portal_conf" <<'EOF'
[preferred]
default=hyprland;gtk
org.freedesktop.impl.portal.Screenshot=hyprland
org.freedesktop.impl.portal.ScreenCast=hyprland
org.freedesktop.impl.portal.FileChooser=gtk
org.freedesktop.impl.portal.Notification=gtk
org.freedesktop.impl.portal.Print=none
EOF
    # Print=none: GTK4 (4.2x) kiest anders ook buiten een sandbox de
    # print-portal. Die dialoog mist de eigen tabbladen van apps, zoals
    # "Page Handling" (passend op pagina) in Papers; de schaal blijft dan op
    # "geen" en grote PDF's vallen van het A4 af. Zonder Print-portal tonen
    # GTK-apps hun eigen printdialoog weer.
    # FileChooser via gnome (Nautilus) faalde buiten GNOME: "kiesvenster ging
    # niet open". De portal leest de keuze alleen bij het starten in.
    systemctl --user try-restart xdg-desktop-portal.service >/dev/null 2>&1 || true
    log_ok "XDG-portalconfiguratie geschreven"
}

# Printdialogen halen het standaardpapier uit LC_PAPER. Met een en_US-locale
# is dat US Letter. We genereren nl_NL.UTF-8 (alleen voor papier/A4) en zetten
# LC_PAPER via ~/.config/kingstra/paper-locale (gelezen in hypr/lua/config.lua
# en doorgegeven aan dbus/systemd in kingstra-session-start).
_phase03_configure_paper() {
    local want="nl_NL.UTF-8"
    local marker="$HOME/.config/kingstra/paper-locale"

    if "${DRY_RUN:-false}"; then
        log_dry "Papier-locale $want zou worden gegenereerd en in $marker gezet"
        return 0
    fi

    if ! locale -a 2>/dev/null | grep -qix 'nl_NL\.utf-\?8'; then
        if [[ -f /etc/locale.gen ]] && grep -qE '^#\s*nl_NL\.UTF-8 UTF-8' /etc/locale.gen; then
            sudo sed -i -E 's/^#\s*(nl_NL\.UTF-8 UTF-8)/\1/' /etc/locale.gen || true
        elif [[ -f /etc/locale.gen ]] && ! grep -qE '^nl_NL\.UTF-8 UTF-8' /etc/locale.gen; then
            echo 'nl_NL.UTF-8 UTF-8' | sudo tee -a /etc/locale.gen >/dev/null || true
        fi
        sudo locale-gen >/dev/null 2>&1 || log_warn "locale-gen mislukte; papier blijft op de standaard van je taal"
    fi

    if locale -a 2>/dev/null | grep -qix 'nl_NL\.utf-\?8'; then
        ensure_dir "$(dirname "$marker")"
        printf '%s\n' "$want" > "$marker"
        log_ok "Standaardpapier A4 (LC_PAPER=$want, actief na opnieuw inloggen)"
    else
        log_warn "Locale $want niet beschikbaar; LC_PAPER niet gezet"
    fi

    # Papers/Evince onthouden het laatst gekozen papier. Stond dat op Letter
    # (door de oude locale), zet het dan eenmalig op A4.
    local f
    for f in "$HOME/.config/papers/print-settings" "$HOME/.config/evince/print-settings"; do
        [[ -f "$f" ]] || continue
        grep -q '^PPDName=Letter$' "$f" || continue
        sed -i -e 's/^PPDName=Letter$/PPDName=A4/' \
               -e 's/^DisplayName=US Letter$/DisplayName=A4/' \
               -e 's/^Width=215\.8.*/Width=210/' \
               -e 's/^Height=279\.3.*/Height=297/' \
               -e 's/^paper-format=na_letter$/paper-format=iso_a4/' \
               -e 's/^paper-width=215\.8.*/paper-width=210/' \
               -e 's/^paper-height=279\.3.*/paper-height=297/' "$f"
        log_ok "Printinstellingen van $(basename "$(dirname "$f")") van Letter naar A4"
    done
}

# Eigen kiezer voor scherm delen (paneel "share" in de shell). XDPH leest
# xdph.conf alleen bij het starten; een eigen xdph.conf zonder onze kop
# blijft staan.
_phase03_configure_share_picker() {
    local conf="$HOME/.config/hypr/xdph.conf"
    local picker="$HOME/.config/hypr/scripts/share-picker.sh"
    if "${DRY_RUN:-false}"; then
        log_dry "Kiezer voor scherm delen zou in $conf komen"
        return 0
    fi
    if [[ -f "$conf" ]] && ! grep -q '^# kingstra-share-picker' "$conf"; then
        log_warn "Eigen $conf gevonden; Kingstra-kiezer voor scherm delen niet ingesteld"
        return 0
    fi
    local new
    new="$(cat <<CONF
# kingstra-share-picker (door de installer geschreven; verwijder deze regel om zelf te beheren)
screencopy {
    custom_picker_binary = $picker
    allow_token_by_default = true
}
CONF
)"
    if [[ -f "$conf" ]] && [[ "$(cat "$conf")" == "$new" ]]; then
        log_ok "Kiezer voor scherm delen staat al"
        return 0
    fi
    printf '%s\n' "$new" > "$conf"
    # Opnieuw starten zodat de nieuwe kiezer meteen geldt; D-Bus start hem
    # zelf weer zodra een app wil delen.
    # Niet herstarten midden in een gesprek waarin je deelt.
    if command -v pw-cli &>/dev/null && pw-cli ls Node 2>/dev/null | grep -q 'xdph-streaming-'; then
        log_info "Je deelt nu je scherm; de nieuwe kiezer geldt na opnieuw inloggen"
    else
        # kingstra-session-start start hem los van systemd, dus try-restart
        # doet dan niets; pkill -x past niet (naam > 15 tekens), vandaar -f.
        if systemctl --user is-active --quiet xdg-desktop-portal-hyprland.service 2>/dev/null; then
            systemctl --user restart xdg-desktop-portal-hyprland.service >/dev/null 2>&1 || true
        else
            pkill -f '^/usr/lib/xdg-desktop-portal-hyprland' >/dev/null 2>&1 || true
        fi
    fi
    log_ok "Kiezer voor scherm delen ingesteld (Kingstra-stijl)"
}

_phase03_validate() {
    validate_cmd Hyprland
    validate_cmd hyprlock
    validate_cmd hypridle
    validate_cmd grim
    validate_cmd slurp
    validate_lua_file "$HOME/.config/hypr/hyprland.lua" "~/.config/hypr/hyprland.lua"
    validate_dir  "$HOME/.config/hypr/lua"           "~/.config/hypr/lua/"
    validate_lua_file "$HOME/.config/hypr/lua/config.lua"    "lua/config.lua"
    validate_lua_file "$HOME/.config/hypr/lua/autostart.lua"  "lua/autostart.lua"
    validate_file "$HOME/.config/hypr/scripts/fingerprint-first-run.sh" "fingerprint-first-run.sh"
    validate_file "$HOME/.config/hypr/scripts/hardware-switches.sh" "hardware-switches.sh"
    validate_file "$HOME/.config/hypr/scripts/hypr-dispatch.sh" "hypr-dispatch.sh"
    validate_file "$HOME/.config/hypr/scripts/lid-lock.sh"       "lid-lock.sh"
    validate_file "$HOME/.config/hypr/scripts/monitor-hotplug-restore.sh" "monitor-hotplug-restore.sh"
    validate_file "$HOME/.config/hypr/scripts/tablet-mode.sh"    "tablet-mode.sh"
    validate_file "$HOME/.local/bin/kingstra-session-start" "kingstra-session-start"
    validate_report
}
