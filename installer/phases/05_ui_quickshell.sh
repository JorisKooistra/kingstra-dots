#!/usr/bin/env bash
# =============================================================================
# Fase 05 — Quickshell UI-laag
# =============================================================================
# Doel:
#   - Quickshell en Qt6-afhankelijkheden installeren
#   - config/quickshell deployen (al via hypr-symlink? nee — eigen map)
#   - 71-autostart-ui.conf aanmaken (start quickshell)
#   - Widget-binds in 82-binds-widgets.conf activeren
# =============================================================================

phase_run() {
    log_step "Pakketten installeren voor Quickshell..."
    _phase05_install_packages

    log_step "Quickshell config deployen..."
    deploy_config "quickshell"

    log_step "UI-autostart aanmaken..."
    _phase05_write_autostart_ui

    log_step "Widget-binds activeren..."
    _phase05_activate_widget_binds

    log_step "Fase 05 valideren..."
    _phase05_validate

    log_ok "Fase 05 voltooid — Quickshell UI-laag staat."
    log_info "Herstart je Hyprland-sessie om de UI-laag te activeren."
    log_info "Of start handmatig:"
    log_info "  awww-daemon &"
    log_info "  quickshell -p ~/.config/quickshell/TopBar.qml &"
    log_info "  quickshell -p ~/.config/quickshell/Main.qml &"
    log_info "  walker --daemon &"
}

# ---------------------------------------------------------------------------

_phase05_install_packages() {
    install_from_manifest "$REPO_ROOT/manifest/packages/ui.txt"
    # Fonts die Quickshell-iconen nodig hebben
    aur_install ttf-material-design-icons-variable
}

_phase05_write_autostart_ui() {
    local autostart_ui="$REPO_ROOT/config/hypr/conf.d/71-autostart-ui.conf"

    if "${DRY_RUN:-false}"; then
        log_dry "71-autostart-ui.conf zou worden aangemaakt"
        return 0
    fi

    cat > "$autostart_ui" <<'EOF'
# =============================================================================
# 71-autostart-ui.conf — UI-laag autostart (aangemaakt door fase 5)
# =============================================================================

# ---------------------------------------------------------------------------
# Wallpaper daemon (awww) + skwd-wall picker daemon
# ---------------------------------------------------------------------------
exec-once = awww-daemon
exec-once = quickshell -p ~/.config/skwd-wall/daemon.qml

# ---------------------------------------------------------------------------
# Quickshell — topbar (één per scherm) en popup master window
# ---------------------------------------------------------------------------
exec-once = quickshell -p ~/.config/quickshell/TopBar.qml
exec-once = quickshell -p ~/.config/quickshell/Main.qml

# ---------------------------------------------------------------------------
# Launcher daemon (elephant + walker)
# elephant moet vóór walker starten (datasource backend)
# ---------------------------------------------------------------------------
exec-once = elephant
exec-once = walker --gapplication-service

# ---------------------------------------------------------------------------
# OSD daemon (volume/brightness overlay via SwayOSD)
# ---------------------------------------------------------------------------
exec-once = swayosd-server
EOF
    log_ok "71-autostart-ui.conf aangemaakt"

    # Zorg dat hyprland.conf het bestand ook inlaadt
    local hyprconf="$REPO_ROOT/config/hypr/hyprland.conf"
    if ! grep -q "71-autostart-ui" "$hyprconf"; then
        sed -i '/source.*70-autostart/a source = ~/.config/hypr/conf.d/71-autostart-ui.conf' "$hyprconf"
        log_ok "71-autostart-ui.conf toegevoegd aan hyprland.conf"
    fi
}

_phase05_activate_widget_binds() {
    local binds_file="$REPO_ROOT/config/hypr/conf.d/82-binds-widgets.conf"

    if "${DRY_RUN:-false}"; then
        log_dry "Quickshell widget-binds zouden worden geactiveerd"
        return 0
    fi

    # Verwijder de # voor de Quickshell IPC-binds
    sed -i 's/^# bind = \$mainMod, \(W\|M\|C\|O\|X\)/bind = $mainMod, \1/' "$binds_file"
    log_ok "Quickshell widget-binds geactiveerd in 82-binds-widgets.conf"
}

_phase05_validate() {
    validate_cmd quickshell
    validate_file "$HOME/.config/quickshell/TopBar.qml"        "TopBar.qml"
    validate_file "$HOME/.config/quickshell/Main.qml"          "Main.qml"
    validate_file "$HOME/.config/quickshell/MatugenColors.qml" "MatugenColors.qml"
    validate_file "$HOME/.config/quickshell/sys_info.sh"       "sys_info.sh"
    validate_file "$HOME/.config/hypr/scripts/qs_manager.sh"   "qs_manager.sh"
    validate_report
}
