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

    # User-state bestanden initialiseren vanuit .default templates
    deploy_defaults "$REPO_ROOT/config/quickshell"

    log_step "Kingstra QML-plugin bouwen/installeren..."
    _phase05_install_kingstra_qml_plugin

    log_step "Intel GPU telemetry-helper bouwen..."
    _phase05_install_intel_gpu_helper

    log_step "UI-autostart aanmaken..."
    _phase05_write_autostart_ui

    log_step "Widget-binds activeren..."
    _phase05_activate_widget_binds

    log_step "Live sessie bijwerken..."
    _phase05_apply_live

    log_step "Fase 05 valideren..."
    _phase05_validate

    log_ok "Fase 05 voltooid — Quickshell UI-laag staat."
}

# ---------------------------------------------------------------------------

_phase05_install_packages() {
    install_from_manifest "$REPO_ROOT/manifest/packages/ui.txt"
    # Supplementair icon-font uit de officiële repo; Nerd Fonts komen in fase 8.
    pacman_install ttf-material-icons
}

_phase05_write_autostart_ui() {
    local autostart_ui="$REPO_ROOT/config/hypr/conf.d/71-autostart-ui.conf"

    if "${DRY_RUN:-false}"; then
        log_dry "71-autostart-ui.conf zou worden bijgewerkt"
        return 0
    fi

    cat > "$autostart_ui" <<'EOF'
# =============================================================================
# 71-autostart-ui.conf — UI-laag autostart (aangemaakt door fase 5)
# =============================================================================
# UI-processen worden gestart door:
#   ~/.local/bin/kingstra-session-start start-ui
#
# Dit bestand blijft bestaan als compatibele include voor hyprland.conf.
EOF
    log_ok "71-autostart-ui.conf bijgewerkt"

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

    # Verwijder de # voor de Quickshell IPC-binds (M=music, C=calendar, O=monitors, X=focustime)
    sed -i 's/^# bind = \$mainMod, \(M\|C\|O\|X\)/bind = $mainMod, \1/' "$binds_file"
    # Activeer theme picker bind
    sed -i 's/^# bind = \$mainMod CTRL, T/bind = $mainMod CTRL, T/' "$binds_file"
    log_ok "Quickshell widget-binds geactiveerd in 82-binds-widgets.conf"
}

_phase05_apply_live() {
    reload_hyprland_live "Quickshell autostart en widget-binds"

    if "${DRY_RUN:-false}"; then
        log_dry "Kingstra UI-entrypoint zou live starten"
        return 0
    fi

    if command -v kingstra-session-start >/dev/null 2>&1; then
        if _phase05_shell_running; then
            kingstra-session-start restart-shell >/dev/null 2>&1 || \
                log_warn "Kingstra shell kon niet live herstarten"
        else
            kingstra-session-start start-ui >/dev/null 2>&1 || \
                log_warn "Kingstra UI-entrypoint kon niet live starten"
        fi
    else
        start_quickshell_path_live "$HOME/.config/quickshell/overview/shell.qml" "Quickshell overview"
    fi
}

_phase05_shell_running() {
    if command -v qs >/dev/null 2>&1; then
        qs list --all 2>/dev/null | grep -Eq \
            "$HOME/.config/quickshell/(TopBar|Main)\\.qml|$HOME/.config/quickshell/overview/shell\\.qml" \
            && return 0
    fi

    pgrep -f "quickshell.*(TopBar|Main|overview/shell)\\.qml" >/dev/null 2>&1
}

_phase05_validate() {
    validate_cmd quickshell
    validate_file "$HOME/.config/quickshell/TopBar.qml"        "TopBar.qml"
    validate_file "$HOME/.config/quickshell/Main.qml"          "Main.qml"
    validate_file "$HOME/.config/quickshell/MatugenColors.qml" "MatugenColors.qml"
    validate_file "$HOME/.config/quickshell/focustime/focus_daemon.py" "FocusTime daemon"
    validate_file "$HOME/.config/quickshell/sys_info.sh"       "sys_info.sh"
    validate_file "$HOME/.config/quickshell/shellsurface/kingstra-intel-gpu-usage" "Intel GPU telemetry helper"
    validate_file "$HOME/.config/hypr/scripts/qs_manager.sh"   "qs_manager.sh"
    validate_file "$HOME/.local/lib/qml/Kingstra/Blobs/qmldir" "Kingstra.Blobs qmldir"
    validate_file "$HOME/.local/lib/qml/Kingstra/Blobs/libkingstrablobs.so" "Kingstra.Blobs plugin"
    validate_report
}

_phase05_install_intel_gpu_helper() {
    local helper_src="$REPO_ROOT/config/quickshell/shellsurface/kingstra-intel-gpu-usage.c"
    local helper_bin="$REPO_ROOT/config/quickshell/shellsurface/kingstra-intel-gpu-usage"

    if [[ ! -f "$helper_src" ]]; then
        log_warn "Intel GPU helperbron ontbreekt: $helper_src — build overgeslagen"
        return 0
    fi

    if ! command -v gcc >/dev/null 2>&1; then
        log_warn "gcc ontbreekt — Intel GPU helper kan niet worden gebouwd"
        return 0
    fi

    if "${DRY_RUN:-false}"; then
        log_dry "Intel GPU helper zou worden gebouwd: $helper_bin"
        log_dry "cap_perfmon zou worden gezet op: $helper_bin"
        return 0
    fi

    if gcc -O2 -Wall -Wextra -o "$helper_bin" "$helper_src"; then
        chmod 755 "$helper_bin"
        log_ok "Intel GPU telemetry-helper gebouwd: $helper_bin"
    else
        log_warn "Intel GPU telemetry-helper build mislukt"
        return 0
    fi

    if command -v setcap >/dev/null 2>&1; then
        if sudo setcap cap_perfmon+ep "$helper_bin" 2>/dev/null; then
            log_ok "cap_perfmon gezet op Intel GPU telemetry-helper"
        else
            log_warn "Kon cap_perfmon niet zetten — GPU-load kan 0 blijven zonder permissie"
            log_info "Handmatig: sudo setcap cap_perfmon+ep '$helper_bin'"
        fi
    else
        log_warn "setcap ontbreekt — GPU-load kan 0 blijven zonder cap_perfmon"
    fi
}

_phase05_install_kingstra_qml_plugin() {
    local plugin_src="$REPO_ROOT/plugin"
    local build_dir="${XDG_CACHE_HOME:-$HOME/.cache}/kingstra/qml-plugin-build"
    local install_prefix="$HOME/.local"

    if [[ ! -f "$plugin_src/CMakeLists.txt" ]]; then
        log_warn "QML-pluginbron ontbreekt: $plugin_src — build overgeslagen"
        return 0
    fi

    if "${DRY_RUN:-false}"; then
        log_dry "Kingstra QML-plugin zou worden gebouwd vanuit $plugin_src"
        log_dry "Install prefix: $install_prefix"
        return 0
    fi

    ensure_dir "$build_dir"
    ensure_dir "$install_prefix/lib/qml"

    local -a generator_args=()
    if command -v ninja >/dev/null 2>&1; then
        generator_args=(-G Ninja)
    fi

    INSTALL_NEXT_RUN_LABEL="CMake configureren: Kingstra QML-plugin" \
        run_cmd cmake -S "$plugin_src" -B "$build_dir" \
            "${generator_args[@]}" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX="$install_prefix"

    INSTALL_NEXT_RUN_LABEL="CMake bouwen: Kingstra QML-plugin" \
        run_cmd cmake --build "$build_dir"

    INSTALL_NEXT_RUN_LABEL="CMake installeren: Kingstra QML-plugin" \
        run_cmd cmake --install "$build_dir"

    log_ok "Kingstra QML-plugin geïnstalleerd in $install_prefix/lib/qml"
}
