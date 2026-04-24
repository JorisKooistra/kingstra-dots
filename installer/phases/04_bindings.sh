#!/usr/bin/env bash
# =============================================================================
# Fase 04 — Definitieve bindingsarchitectuur
# =============================================================================
# Doel:
#   - Bind-bestanden uitrollen (overschrijft de stubs van fase 3)
#   - Dubbele binds controleren
#   - Keybindings documenteren
# Noot:
#   Config is al via symlink aanwezig (fase 3 deed deploy_config "hypr").
#   Fase 4 schrijft alleen de inhoud van de bind-bestanden — geen nieuwe symlinks.
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
    # Haal alle bind/binde/bindm-regels op uit de bind-bestanden
    local bind_files=(
        "$REPO_ROOT/config/hypr/conf.d/80-binds-core.conf"
        "$REPO_ROOT/config/hypr/conf.d/81-binds-apps.conf"
        "$REPO_ROOT/config/hypr/conf.d/82-binds-widgets.conf"
        "$REPO_ROOT/config/hypr/conf.d/83-binds-media.conf"
        "$REPO_ROOT/config/hypr/conf.d/84-binds-screenshots.conf"
    )

    # Extraheer "MOD, KEY" combinaties en zoek duplicaten
    local duplicates
    duplicates="$(
        grep -h -i '^\s*bind[a-z]* ' "${bind_files[@]}" 2>/dev/null \
        | sed 's/^\s*bind[a-z]*\s*=\s*//' \
        | awk -F',' '{gsub(/ /,"",$1); gsub(/ /,"",$2); print tolower($1) "," tolower($2)}' \
        | sort | uniq -d
    )"

    if [[ -n "$duplicates" ]]; then
        log_warn "Mogelijke dubbele bind-combinaties gevonden:"
        while IFS= read -r line; do
            log_warn "  $line"
        done <<< "$duplicates"
    else
        log_ok "Geen dubbele binds gevonden."
    fi
}

_phase04_validate() {
    local -a bind_files=(
        "80-binds-core.conf"
        "81-binds-apps.conf"
        "82-binds-widgets.conf"
        "83-binds-media.conf"
        "84-binds-screenshots.conf"
    )
    for f in "${bind_files[@]}"; do
        validate_file "$HOME/.config/hypr/conf.d/$f" "$f"
    done
    validate_report
}
