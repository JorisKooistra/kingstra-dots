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

    log_step "Apply-script deployen..."
    _phase08_deploy_apply_script

    log_step "Eerste kleurapplicatie uitvoeren..."
    _phase08_initial_apply

    log_step "Fase 08 valideren..."
    validate_cmd matugen
    validate_file "$HOME/.config/matugen/config.toml"        "matugen/config.toml"
    validate_dir  "$HOME/.config/matugen/templates"          "matugen/templates/"
    validate_file "$HOME/.local/bin/kingstra-theme-apply"    "kingstra-theme-apply"
    validate_report

    log_ok "Fase 08 voltooid — Matugen is de enige theme-engine."
    log_info "Handmatig toepassen: kingstra-theme-apply <pad/naar/wallpaper>"
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
