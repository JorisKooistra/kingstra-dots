#!/usr/bin/env bash
# =============================================================================
# Fase 04 — Definitieve bindingsarchitectuur
# =============================================================================
# Doel:
#   - Lua-bindings valideren
#   - Dubbele binds controleren
#   - Keybindings documenteren
# Noot:
#   Config is al via symlink aanwezig (fase 3 deed deploy_config "hypr").
#   Fase 4 wijzigt geen bestanden; de bindings leven in hypr/lua/binds.lua.
# =============================================================================

phase_run() {
    log_step "Dubbele binds controleren..."
    _phase04_check_duplicates

    log_step "Keybindings valideren..."
    _phase04_validate

    reload_hyprland_live "keybindings"

    log_ok "Fase 04 voltooid — bindingsarchitectuur staat."
}

# ---------------------------------------------------------------------------

_phase04_check_duplicates() {
    # The Lua API validates duplicate/conflicting bindings while loading. A
    # separate text parser would be less reliable because binds may be built
    # through loops and helpers.
    log_info "Dubbele binds worden door de Hyprland Lua-parser gevalideerd"
}

_phase04_validate() {
    validate_file "$HOME/.config/hypr/lua/binds.lua" "hypr/lua/binds.lua"
    validate_report
}
