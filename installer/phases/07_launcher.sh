#!/usr/bin/env bash
# =============================================================================
# Fase 07 — Launcherlaag (Walker)
# =============================================================================

phase_run() {
    log_step "Walker + Elephant installeren..."
    aur_install walker-bin
    aur_install elephant
    aur_install elephant-desktopapplications-bin
    aur_install elephant-providerlist-bin

    log_step "Walker config deployen..."
    deploy_config "walker"

    log_step "Fase 07 valideren..."
    validate_cmd walker
    validate_cmd elephant
    validate_file "$HOME/.config/walker/config.toml" "walker/config.toml"
    validate_file "$HOME/.config/walker/style.css"   "walker/style.css"
    validate_report

    log_ok "Fase 07 voltooid — Walker + Elephant geïnstalleerd (Super+Ctrl+Return)."
}
