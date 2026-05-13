#!/usr/bin/env bash
# =============================================================================
# migrate.sh — Voorbereiding bij migratie vanaf andere dotfile-stacks
# =============================================================================

ML4W_DETECTED=false

_MIGRATE_ML4W_PATHS=(
    "$HOME/.config/com.ml4w.hyprlandsettings"
    "$HOME/.config/ml4w"
    "$HOME/.config/ml4w-dotfiles-settings"
    "$HOME/.config/nwg-dock-hyprland"
    "$HOME/.config/rofi"
    "$HOME/.config/waybar"
    "$HOME/.config/waypaper"
    "$HOME/.config/wallust"
    "$HOME/.config/wlogout"
)

_detect_ml4w_stack() {
    if [[ -L "$HOME/.config/ml4w" ]] || [[ -d "$HOME/.config/ml4w" ]]; then
        ML4W_DETECTED=true
    elif [[ -f "$HOME/.config/ml4w-dotfiles-installer/active.json" ]]; then
        ML4W_DETECTED=true
    elif [[ -d "$HOME/.mydotfiles/com.ml4w.dotfiles.stable" ]]; then
        ML4W_DETECTED=true
    else
        ML4W_DETECTED=false
    fi

    export ML4W_DETECTED
}

_migration_stop_process_if_running() {
    local name="$1"

    if "${DRY_RUN:-false}"; then
        log_dry "Conflict-proces zou worden gestopt: $name"
        return 0
    fi

    if pgrep -x "$name" >/dev/null 2>&1; then
        pkill -x "$name" >/dev/null 2>&1 || true
        log_ok "Conflict-proces gestopt: $name"
    fi
}

_migration_disable_user_unit_if_present() {
    local unit="$1"

    if "${DRY_RUN:-false}"; then
        log_dry "Conflicterende user-service zou worden uitgeschakeld: $unit"
        return 0
    fi

    if ! command -v systemctl >/dev/null 2>&1; then
        return 0
    fi

    if systemctl --user list-unit-files --no-legend 2>/dev/null | grep -q "^${unit}[[:space:]]"; then
        systemctl --user disable --now "$unit" >/dev/null 2>&1 || true
        log_ok "Conflicterende user-service uitgeschakeld: $unit"
    fi
}

migration_prepare_existing_setup() {
    _detect_ml4w_stack

    if [[ "${ML4W_DETECTED:-false}" != "true" ]]; then
        return 0
    fi

    log_warn "ML4W dotfiles gedetecteerd — migratiemodus actief."
    log_info "Bestaande ML4W-paden worden extra geback-upt; pakketten worden niet verwijderd."

    backup_paths "${_MIGRATE_ML4W_PATHS[@]}"

    _migration_disable_user_unit_if_present "waybar.service"
    _migration_disable_user_unit_if_present "waypaper.service"
    _migration_disable_user_unit_if_present "hyprpaper.service"
    _migration_disable_user_unit_if_present "swww-daemon.service"

    _migration_stop_process_if_running "waybar"
    _migration_stop_process_if_running "waypaper"
    _migration_stop_process_if_running "hyprpaper"
    _migration_stop_process_if_running "swww-daemon"
    _migration_stop_process_if_running "qs"
    _migration_stop_process_if_running "quickshell"
    _migration_stop_process_if_running "walker"
    _migration_stop_process_if_running "swaync"

    log_info "ML4W-migratievoorbereiding klaar — Kingstra neemt de sessie-autostart over."
}
