#!/usr/bin/env bash
# =============================================================================
# Fase 08 — Theminglaag (Matugen + Kingstra scripts)
# =============================================================================
# Doel:
#   - Matugen installeren
#   - config/matugen deployen (templates)
#   - config/kingstra deployen (themes, modes, state)
#   - Alle kingstra-scripts naar ~/.local/bin/ linken
#   - Eerste kleurapplicatie draaien op de huidige wallpaper
# =============================================================================

phase_run() {
    log_step "Matugen installeren..."
    aur_install matugen-bin

    log_step "Matugen config deployen..."
    deploy_config "matugen"

    log_step "Thema- en mode-bestanden deployen..."
    deploy_config "kingstra"

    log_step "Apply-script deployen..."
    _phase08_deploy_apply_script

    log_step "Thema-scripts deployen..."
    _phase08_deploy_theme_scripts

    log_step "State-scripts deployen..."
    _phase08_deploy_state_scripts

    log_step "Mode-scripts deployen..."
    _phase08_deploy_mode_scripts

    log_step "Standaard thema-config genereren..."
    _phase08_default_theme_conf

    log_step "Game launcher installeren..."
    _phase08_install_game_launcher

    log_step "Eerste kleurapplicatie uitvoeren..."
    _phase08_initial_apply

    log_step "Fase 08 valideren..."
    validate_cmd matugen
    validate_dir  "$HOME/.config/matugen/templates"               "matugen/templates/"
    validate_file "$HOME/.local/bin/kingstra-theme-apply"         "kingstra-theme-apply"
    validate_file "$HOME/.local/bin/kingstra-theme-switch"        "kingstra-theme-switch"
    validate_file "$HOME/.local/bin/kingstra-theme-read"          "kingstra-theme-read"
    validate_file "$HOME/.local/bin/apply-shell-state"            "apply-shell-state"
    validate_file "$HOME/.local/bin/kingstra-state-read"          "kingstra-state-read"
    validate_file "$HOME/.local/bin/kingstra-state-write"         "kingstra-state-write"
    validate_file "$HOME/.local/bin/kingstra-session-update"      "kingstra-session-update"
    validate_file "$HOME/.local/bin/kingstra-mode-switch"         "kingstra-mode-switch"
    validate_file "$HOME/.local/bin/kingstra-mode-read"           "kingstra-mode-read"
    validate_file "$HOME/.local/bin/kingstra-color-transform"     "kingstra-color-transform"
    validate_dir  "$HOME/.config/kingstra/themes"                 "kingstra/themes/"
    validate_dir  "$HOME/.config/kingstra/modes"                  "kingstra/modes/"
    validate_cmd  quickshell-game
    validate_file "$HOME/.config/quickshell/game-launcher/config.toml" "game-launcher/config.toml"
    validate_report

    log_ok "Fase 08 voltooid."
    log_info "Thema wisselen:      kingstra-theme-switch <thema_naam>"
    log_info "Mode wisselen:       kingstra-mode-switch <office|gaming|media>"
    log_info "State toepassen:     apply-shell-state"
    log_info "Game launcher:       quickshell-game  (of Super+Alt+G)"
}

# ---------------------------------------------------------------------------

_phase08_deploy_apply_script() {
    local script_src="$REPO_ROOT/config/shared/scripts/matugen-apply.sh"
    local script_dest="$HOME/.local/bin/kingstra-theme-apply"

    if "${DRY_RUN:-false}"; then
        log_dry "Apply-script zou worden gedeployed: $script_dest"
        return 0
    fi

    ensure_dir "$HOME/.local/bin"
    deploy_link "$script_src" "$script_dest"
    chmod +x "$script_src"
    log_ok "Apply-script beschikbaar als: kingstra-theme-apply"
}

_phase08_deploy_theme_scripts() {
    local switch_src="$REPO_ROOT/config/shared/scripts/kingstra-theme-switch"
    local switch_dest="$HOME/.local/bin/kingstra-theme-switch"
    local read_src="$REPO_ROOT/config/shared/scripts/kingstra-theme-read.py"
    local read_dest="$HOME/.local/bin/kingstra-theme-read"

    if "${DRY_RUN:-false}"; then
        log_dry "Theme-scripts zouden worden gedeployed"
        return 0
    fi

    ensure_dir "$HOME/.local/bin"
    deploy_link "$switch_src" "$switch_dest"
    chmod +x "$switch_src"
    deploy_link "$read_src" "$read_dest"
    chmod +x "$read_src"
    log_ok "Thema-scripts beschikbaar: kingstra-theme-switch, kingstra-theme-read"
}

_phase08_deploy_state_scripts() {
    local scripts_dir="$REPO_ROOT/config/shared/scripts"

    if "${DRY_RUN:-false}"; then
        log_dry "State-scripts zouden worden gedeployed"
        return 0
    fi

    ensure_dir "$HOME/.local/bin"

    local -A state_scripts=(
        ["kingstra-state-read"]="kingstra-state-read"
        ["kingstra-state-write"]="kingstra-state-write"
        ["kingstra-session-update"]="kingstra-session-update"
        ["apply-shell-state"]="apply-shell-state"
        ["kingstra-color-transform"]="kingstra-color-transform"
    )

    for src_name in "${!state_scripts[@]}"; do
        local dest_name="${state_scripts[$src_name]}"
        local src="$scripts_dir/$src_name"
        local dest="$HOME/.local/bin/$dest_name"
        deploy_link "$src" "$dest"
        chmod +x "$src"
    done

    log_ok "State-scripts beschikbaar: kingstra-state-read/write, kingstra-session-update, apply-shell-state, kingstra-color-transform"
}

_phase08_deploy_mode_scripts() {
    local scripts_dir="$REPO_ROOT/config/shared/scripts"

    if "${DRY_RUN:-false}"; then
        log_dry "Mode-scripts zouden worden gedeployed"
        return 0
    fi

    ensure_dir "$HOME/.local/bin"

    deploy_link "$scripts_dir/kingstra-mode-switch" "$HOME/.local/bin/kingstra-mode-switch"
    chmod +x "$scripts_dir/kingstra-mode-switch"

    deploy_link "$scripts_dir/kingstra-mode-read" "$HOME/.local/bin/kingstra-mode-read"
    chmod +x "$scripts_dir/kingstra-mode-read"

    log_ok "Mode-scripts beschikbaar: kingstra-mode-switch, kingstra-mode-read"
}

_phase08_default_theme_conf() {
    local theme_conf="$HOME/.config/hypr/conf.d/35-theme.conf"

    if "${DRY_RUN:-false}"; then
        log_dry "Standaard 35-theme.conf zou worden aangemaakt"
        return 0
    fi

    # Only create if it doesn't exist yet (don't overwrite user's active theme)
    if [[ ! -f "$theme_conf" ]]; then
        ensure_dir "$(dirname "$theme_conf")"
        cat > "$theme_conf" <<'CONF'
# =============================================================================
# 35-theme.conf — Automatisch gegenereerd door kingstra-theme-switch
# Thema: (geen — standaard)
# =============================================================================
CONF
        log_ok "Standaard 35-theme.conf aangemaakt"
    else
        log_info "35-theme.conf bestaat al — niet overschreven"
    fi
}

_phase08_install_game_launcher() {
    if "${DRY_RUN:-false}"; then
        log_dry "quickshell-games-launchers-git zou worden geïnstalleerd"
        return 0
    fi

    # Installeer AUR package (levert /usr/bin/quickshell-game)
    aur_install quickshell-games-launchers-git

    # Python dependencies
    if command -v pip &>/dev/null; then
        pip install --quiet --user vdf toml 2>/dev/null || \
            log_warn "pip install vdf/toml mislukt — installeer handmatig"
    fi

    # Zorg dat de config directory bestaat (symlink via deploy_config "quickshell")
    local cfg_dir="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/game-launcher"
    ensure_dir "$cfg_dir"

    # Initialiseer user-config als quickshell-game dat nog niet heeft gedaan
    if [[ ! -f "$cfg_dir/config.toml" ]]; then
        quickshell-game --init 2>/dev/null || true
    fi

    log_ok "Game launcher beschikbaar: quickshell-game (Super+Alt+G)"
}

_phase08_initial_apply() {
    local session_file="${XDG_CONFIG_HOME:-$HOME/.config}/kingstra/state/session.json"
    local cache_file="${XDG_CACHE_HOME:-$HOME/.cache}/kingstra/last-wallpaper"

    if "${DRY_RUN:-false}"; then
        log_dry "Eerste kleurapplicatie zou worden uitgevoerd"
        return 0
    fi

    # Probeer wallpaper uit session.json te lezen, daarna fallback naar cache
    local wallpaper=""
    if [[ -f "$session_file" ]]; then
        wallpaper=$(jq -r '.wallpaper // ""' "$session_file" 2>/dev/null || echo "")
    fi
    if [[ -z "$wallpaper" || ! -f "$wallpaper" ]] && [[ -f "$cache_file" ]]; then
        wallpaper="$(cat "$cache_file")"
    fi

    if [[ -n "$wallpaper" && -f "$wallpaper" ]]; then
        log_step "Eerste kleurapplicatie op: $wallpaper"
        "$HOME/.local/bin/apply-shell-state" || \
            log_warn "apply-shell-state mislukt — handmatig uitvoeren na sessiestart"
    else
        log_info "Nog geen wallpaper in staat — kleuren worden toegepast bij eerste wallpaperwissel (fase 9)"
    fi
}
