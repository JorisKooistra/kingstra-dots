#!/usr/bin/env bash
# =============================================================================
# Fase 07 — Launcherlaag (Walker)
# =============================================================================

phase_run() {
    log_step "Walker installeren..."
    aur_install walker-bin

    log_step "Walker config deployen..."
    deploy_config "walker"

    log_step "Fase 07 valideren..."
    validate_cmd walker
    validate_file "$HOME/.config/walker/config.toml" "walker/config.toml"
    validate_file "$HOME/.config/walker/style.css"   "walker/style.css"
    validate_report

    log_ok "Fase 07 voltooid — Walker is de hoofdlauncher (Super+Ctrl+Return)."
}
