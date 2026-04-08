#!/usr/bin/env bash
# =============================================================================
# Fase 08 — Theminglaag (Matugen)
# =============================================================================
# Doel:
#   - Matugen installeren
#   - config/matugen deployen (config.toml + templates)
#   - apply-script deployen
#   - Eerste kleurapplicatie draaien op de huidige wallpaper
# =============================================================================

phase_run() {
    log_step "Matugen installeren..."
    aur_install matugen-bin

    log_step "Matugen config deployen..."
    deploy_config "matugen"

    log_step "Thema-bestanden deployen..."
    deploy_config "kingstra"

    log_step "Apply-script deployen..."
    _phase08_deploy_apply_script

    log_step "Thema-scripts deployen..."
    _phase08_deploy_theme_scripts

    log_step "Standaard thema-config genereren..."
    _phase08_default_theme_conf

    log_step "Eerste kleurapplicatie uitvoeren..."
    _phase08_initial_apply

    log_step "Fase 08 valideren..."
    validate_cmd matugen
    validate_file "$HOME/.config/matugen/config.toml"        "matugen/config.toml"
    validate_dir  "$HOME/.config/matugen/templates"          "matugen/templates/"
    validate_file "$HOME/.local/bin/kingstra-theme-apply"    "kingstra-theme-apply"
    validate_file "$HOME/.local/bin/kingstra-theme-switch"   "kingstra-theme-switch"
    validate_file "$HOME/.local/bin/kingstra-theme-read"     "kingstra-theme-read"
    validate_dir  "$HOME/.config/kingstra/themes"            "kingstra/themes/"
    validate_report

    log_ok "Fase 08 voltooid — Matugen is de enige theme-engine."
    log_info "Handmatig toepassen: kingstra-theme-apply <pad/naar/wallpaper>"
    log_info "Thema wisselen: kingstra-theme-switch <thema_naam>"
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

_phase08_initial_apply() {
    local state_file="${XDG_CACHE_HOME:-$HOME/.cache}/kingstra/last-wallpaper"

    if "${DRY_RUN:-false}"; then
        log_dry "Eerste kleurapplicatie zou worden uitgevoerd"
        return 0
    fi

    if [[ -f "$state_file" ]]; then
        local wallpaper
        wallpaper="$(cat "$state_file")"
        if [[ -f "$wallpaper" ]]; then
            log_step "Kleuren toepassen op: $wallpaper"
            "$HOME/.local/bin/kingstra-theme-apply" "$wallpaper" || \
                log_warn "Kleurapplicatie mislukt — handmatig uitvoeren na sessiestart"
            return 0
        fi
    fi

    log_info "Nog geen wallpaper in staat — kleuren worden toegepast bij eerste wallpaperwissel (fase 9)"
}
