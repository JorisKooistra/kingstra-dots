#!/usr/bin/env bash
# =============================================================================
# Fase 09 — Wallpapermodule
# =============================================================================
# Doel:
#   - skwd-wall en optioneel mpvpaper installeren
#   - kingstra-wallpaper orchestrator deployen naar ~/.local/bin/
#   - Wallpaper-map aanmaken als die nog niet bestaat
#   - Voorbeeldwallpaper plaatsen als map leeg is (gegenereerde kleur-gradient)
# =============================================================================

phase_run() {
    log_step "Wallpaper-pakketten installeren..."
    aur_install skwd-wall               # standalone skwd-wall CLI + user daemon
    pacman_install imagemagick          # voor gradient-fallback + manipulatie
    pacman_install python-pillow        # thumbnail-cache + Mono Accent beeldbewerking
    pacman_install qt6-shadertools       # eigen picker-kaartshader (qsb)
    pacman_install python-numpy          # Mono Accent pixelmasker
    pacman_install ffmpeg               # voor videothumbnails / -verwerking
    pacman_install sqlite               # walker/history dep, ook nuttig voor indexer
    pacman_install inotify-tools        # voor live-reloadwatcher (optioneel)
    pacman_install chafa                # ASCII/pixel-preview in fzf picker

    log_step "skwd-wall config aanmaken..."
    _phase09_write_skwd_wall_config

    log_step "Eigen Kingstra wallpaper-picker aansluiten..."
    _phase09_use_native_picker
    _phase09_register_picker

    log_step "skwd-wall user-service activeren..."
    _phase09_enable_skwd_daemon

    log_step "Videowallpaper-pakket installeren (mpvpaper)..."
    _phase09_install_mpvpaper

    log_step "Wallpaper-orchestrator deployen..."
    _phase09_deploy_orchestrator

    log_step "Wallpaper-map aanmaken..."
    _phase09_ensure_wallpaper_dir

    log_step "Fase 09 valideren..."
    if "${DRY_RUN:-false}"; then
        log_dry "Commando-check overgeslagen (dry-run): skwd"
    else
        validate_cmd skwd
    fi
    validate_file "$HOME/.config/skwd-wall/config.json"    "skwd-wall/config.json"
    validate_file "$HOME/.local/bin/kingstra-wallpaper"    "kingstra-wallpaper"
    validate_file "$HOME/.local/bin/kingstra-skwd-wallpaper-sync" "kingstra-skwd-wallpaper-sync"
    validate_file "$REPO_ROOT/config/quickshell/WallpaperPicker.qml" "Kingstra wallpaper-picker"
    validate_file "$REPO_ROOT/config/quickshell/wallpaper/backend.py" "Kingstra picker worker"
    validate_file "${XDG_DATA_HOME:-$HOME/.local/share}/applications/kingstra-wallpaper-picker.desktop" "Kingstra picker app-registratie"
    validate_dir  "$HOME/Pictures/Wallpapers"              "Pictures/Wallpapers"
    validate_file "${XDG_CACHE_HOME:-$HOME/.cache}/kingstra/last-wallpaper" "last-wallpaper state"
    _phase09_validate_skwd_daemon
    validate_report

    log_ok "Fase 09 voltooid — Wallpapermodule actief."
    log_info "Wallpaper instellen: kingstra-wallpaper set <bestand>"
    log_info "Interactieve kiezer: kingstra-wallpaper pick"
    log_info "Kingstra picker:    ~/.config/hypr/scripts/wallpaper-picker-safe.sh"
    log_info "Willekeurig:        kingstra-wallpaper random"
    log_info "Videowallpaper:     kingstra-wallpaper video <bestand>"
}

# ---------------------------------------------------------------------------

_phase09_write_skwd_wall_config() {
    local config_dest="$HOME/.config/skwd-wall/config.json"

    if "${DRY_RUN:-false}"; then
        log_dry "skwd-wall config.json zou worden aangemaakt: $config_dest"
        return 0
    fi

    if [[ -f "$config_dest" ]]; then
        log_info "skwd-wall config.json bestaat al — matugen integratie uitschakelen voor centrale Kingstra pipeline"
        backup_path "$config_dest"
        _phase09_disable_skwd_matugen "$config_dest"
        return 0
    fi

    ensure_dir "$(dirname "$config_dest")"

    cat > "$config_dest" <<'EOF'
{
    "compositor": "hyprland",
    "monitor": "",
    "paths": {
        "wallpaper": "~/Pictures/Wallpapers",
        "videoWallpaper": "~/Pictures/Wallpapers/video",
        "cache": "",
        "templates": "",
        "scripts": "",
        "steam": "",
        "steamWorkshop": "",
        "steamWeAssets": ""
    },
    "features": {
        "matugen": false,
        "ollama": false,
        "steam": false,
        "wallhaven": true
    },
    "colorSource": "magick",
    "ollama": { "url": "http://localhost:11434", "model": "gemma3:4b" },
    "steam": { "apiKey": "", "username": "" },
    "wallhaven": { "apiKey": "" },
    "matugen": { "schemeType": "scheme-fidelity" },
    "integrations": [
        { "name": "skwd-wall", "template": "quickshell-colors.json", "output": "~/.config/quickshell/colors.json" },
        { "name": "kitty", "template": "kitty.conf", "output": "~/.config/kitty/skwd-theme.generated.conf", "reload": "pkill -USR1 kitty" },
        { "name": "vscode", "template": "vscode-theme.json", "output": "~/.vscode/extensions/matugen.matugen-theme-1.0.0/themes/matugen-color-theme.json" },
        { "name": "vesktop", "template": "vesktop.css", "output": "~/.config/vesktop/themes/kitty-match.css" },
        { "name": "spicetify", "template": "spicetify.ini", "output": "~/.config/spicetify/Themes/Matugen/color.ini", "reload": "~/.config/skwd-wall/scripts/reload-spicetify.sh" },
        { "name": "spicetify-css", "template": "spicetify.css", "output": "~/.config/spicetify/Themes/Matugen/user.css" },
        { "name": "qt6ct", "template": "qt6ct-colors.conf", "output": "~/.config/qt6ct/colors/matugen.conf" },
        { "name": "yazi", "template": "yazi-theme.toml", "output": "~/.config/yazi/theme.toml" }
    ],
    "components": {
        "wallpaperSelector": {
            "displayMode": "slices",
            "showColorDots": true,
            "sliceSpacing": -30,
            "hexScrollStep": 1,
            "customPresets": {}
        }
    },
    "wallpaperMute": true,
    "postProcessing": [
        { "command": "~/.local/bin/apply-shell-state --renderer-hook --wallpaper \"%path%\"", "type": "static" }
    ],
    "performance": {
        "imageOptimizePreset": "balanced",
        "imageOptimizeResolution": "2k"
    }
}
EOF
    log_ok "skwd-wall config.json aangemaakt: $config_dest"
    _phase09_disable_skwd_matugen "$config_dest"
}

_phase09_use_native_picker() {
    local override="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/skwd-daemon.service.d/10-kingstra-overlay.conf"
    if "${DRY_RUN:-false}"; then
        log_dry "Oude Kingstra picker-override zou worden verwijderd: $override"
        return 0
    fi
    # Alleen onze oude override; andere service-aanpassingen blijven staan.
    if [[ -f "$override" ]] && grep -q 'Environment=SKWD_SHELL_QML=.*kingstra/skwd-wall-overlay/shell.qml' "$override"; then
        backup_path "$override"
        rm -- "$override"
        systemctl --user daemon-reload >/dev/null 2>&1 || true
    fi
    log_ok "Eigen picker beschikbaar; geen upstream QML-patches nodig"
}

_phase09_register_picker() {
    local apps_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
    local desktop="$apps_dir/kingstra-wallpaper-picker.desktop"
    local launcher="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/wallpaper-picker-safe.sh"
    if "${DRY_RUN:-false}"; then
        log_dry "Picker app-registratie zou worden geschreven: $desktop"
        return 0
    fi
    ensure_dir "$apps_dir"
    cat > "$desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Kingstra Wallpapers
Comment=Wallpapers kiezen uit je collectie of Wallhaven
Exec=bash "$launcher"
Icon=preferences-desktop-wallpaper
Terminal=false
NoDisplay=true
Categories=Settings;DesktopSettings;
StartupWMClass=kingstra-wallpaper-picker
DESKTOP
    command -v update-desktop-database >/dev/null 2>&1 \
        && update-desktop-database "$apps_dir" >/dev/null 2>&1 || true
    log_ok "Picker geregistreerd voor desktop-portals"
}

_phase09_enable_skwd_daemon() {
    if "${DRY_RUN:-false}"; then
        log_dry "skwd-daemon.service zou worden ingeschakeld"
        return 0
    fi

    if ! command -v systemctl &>/dev/null; then
        log_warn "systemctl niet gevonden — skwd-daemon service niet geactiveerd"
        return 0
    fi

    if systemctl --user enable --now skwd-daemon.service >/dev/null 2>&1; then
        systemctl --user restart skwd-daemon.service >/dev/null 2>&1 || true
        log_ok "skwd-daemon.service actief"
    else
        log_warn "Kon skwd-daemon.service niet direct starten — Hyprland autostart probeert dit opnieuw"
    fi
}

_phase09_validate_skwd_daemon() {
    if "${DRY_RUN:-false}"; then
        log_dry "Service-check overgeslagen (dry-run): skwd-daemon.service"
        return 0
    fi

    local service_file
    for service_file in \
        "$HOME/.config/systemd/user/skwd-daemon.service" \
        "/etc/systemd/user/skwd-daemon.service" \
        "/usr/lib/systemd/user/skwd-daemon.service"; do
        if [[ -f "$service_file" ]]; then
            log_ok "User-service aanwezig: skwd-daemon.service"
            return 0
        fi
    done

    log_error "User-service ontbreekt: skwd-daemon.service"
    (( VALIDATE_ERRORS++ )) || true
}

_phase09_disable_skwd_matugen() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        return 0
    fi

    if ! command -v jq &>/dev/null; then
        log_warn "jq niet gevonden — skwd-wall matugen setting niet aangepast"
        return 0
    fi

    local tmp_file
    tmp_file="$(mktemp)"

    if jq '
        .features.matugen = false
        | .features.wallhaven = true
        | .matugen.schemeType = "scheme-tonal-spot"
        | .postProcessing = (
            (.postProcessing // [])
            | map(select(
                if type == "string" then
                    contains("apply-shell-state") | not
                else
                    ((.command // "") | contains("apply-shell-state") | not)
                end
            ))
            + [{"command":"~/.local/bin/apply-shell-state --renderer-hook --wallpaper \"%path%\"","type":"static"}]
        )
    ' "$config_file" > "$tmp_file" 2>/dev/null; then
        mv "$tmp_file" "$config_file"
        log_ok "skwd-wall matugen integratie uitgeschakeld: $config_file"
    else
        rm -f "$tmp_file"
        log_warn "Kon skwd-wall config niet patchen: $config_file"
    fi
}

_phase09_install_mpvpaper() {
    # Altijd installeren als profiel video-wallpaper toestaat
    local enable_video="${ENABLE_VIDEO_WALLPAPER:-false}"

    if [[ "$enable_video" == "true" ]]; then
        log_info "ENABLE_VIDEO_WALLPAPER=true — mpvpaper installeren"
        aur_install mpvpaper
    else
        log_info "ENABLE_VIDEO_WALLPAPER=false — mpvpaper overgeslagen"
        log_info "  Zet ENABLE_VIDEO_WALLPAPER=true in je profiel om videowallpapers in te schakelen."
    fi
}

_phase09_deploy_orchestrator() {
    local script_src="$REPO_ROOT/config/wallpaper/kingstra-wallpaper"
    local script_dest="$HOME/.local/bin/kingstra-wallpaper"
    local bridge_src="$REPO_ROOT/config/wallpaper/kingstra-skwd-wallpaper-sync"
    local bridge_dest="$HOME/.local/bin/kingstra-skwd-wallpaper-sync"

    if "${DRY_RUN:-false}"; then
        log_dry "Orchestrator zou worden gedeployed: $script_dest"
        return 0
    fi

    ensure_dir "$HOME/.local/bin"
    deploy_link "$script_src" "$script_dest"
    deploy_link "$bridge_src" "$bridge_dest"
    chmod +x "$script_src"
    chmod +x "$bridge_src"
    log_ok "Orchestrator beschikbaar als: kingstra-wallpaper"
    log_ok "Compatibele picker-launcher beschikbaar als: kingstra-skwd-wallpaper-sync"
}

_phase09_ensure_wallpaper_dir() {
    local wdir="$HOME/Pictures/Wallpapers"
    local default_src="$REPO_ROOT/assets/wallpapers/wallhaven-mlwz78.png"
    local default_dest="$wdir/wallhaven-mlwz78.png"

    if "${DRY_RUN:-false}"; then
        log_dry "Wallpaper-map zou worden aangemaakt: $wdir"
        log_dry "Standaard wallpaper zou worden geplaatst: $default_dest"
        return 0
    fi

    if [[ ! -d "$wdir" ]]; then
        mkdir -p "$wdir"
        log_ok "Wallpaper-map aangemaakt: $wdir"
    else
        log_info "Wallpaper-map bestaat al: $wdir"
    fi

    if [[ -f "$default_src" && ! -f "$default_dest" ]]; then
        cp "$default_src" "$default_dest"
        log_ok "Standaard wallpaper geplaatst: $default_dest"
    elif [[ -f "$default_dest" ]]; then
        log_info "Standaard wallpaper bestaat al: $default_dest"
    else
        log_warn "Standaard wallpaper asset ontbreekt: $default_src"
    fi

    _phase09_seed_default_wallpaper_state "$default_dest"

    # Genereer een fallbackwallpaper als de map leeg is
    local count
    count="$(find "$wdir" -maxdepth 2 -type f \
        \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) \
        2>/dev/null | wc -l)"

    if [[ "$count" -eq 0 ]]; then
        _phase09_generate_fallback_wallpaper "$wdir"
    elif [[ ! -f "${XDG_CACHE_HOME:-$HOME/.cache}/kingstra/last-wallpaper" ]]; then
        _phase09_set_initial_wallpaper_from_dir "$wdir"
    fi
}

_phase09_seed_default_wallpaper_state() {
    local wallpaper="$1"
    [[ -f "$wallpaper" ]] || return 0

    local state_dir="${XDG_CACHE_HOME:-$HOME/.cache}/kingstra"
    local config_state_dir="${XDG_CONFIG_HOME:-$HOME/.config}/kingstra/state"
    local last_wallpaper="$state_dir/last-wallpaper"

    mkdir -p "$state_dir" "$config_state_dir"

    local current_wallpaper=""
    current_wallpaper="$(cat "$last_wallpaper" 2>/dev/null || true)"

    if [[ -z "$current_wallpaper" || ! -f "$current_wallpaper" ]]; then
        echo "$wallpaper" > "$last_wallpaper"
        echo "static" > "$state_dir/wallpaper-mode"
        echo "$wallpaper" > "$state_dir/last-image-wallpaper"
        _phase09_sync_skwd_cache "$wallpaper" "static"

        jq -n \
            --arg name "$(basename "$wallpaper")" \
            --arg path "$wallpaper" \
            '{"name":$name,"path":$path}' \
            > "$config_state_dir/wallpaper.json" || true

        log_ok "Standaard wallpaper ingesteld in state: $wallpaper"
        _phase09_apply_initial_wallpaper "$wallpaper"
    else
        log_info "Bestaande wallpaper-state behouden: $current_wallpaper"
    fi
}

_phase09_generate_fallback_wallpaper() {
    local wdir="$1"
    local out="$wdir/kingstra-default.png"

    if "${DRY_RUN:-false}"; then
        log_dry "Fallbackwallpaper zou worden gegenereerd: $out"
        return 0
    fi

    if ! command -v magick &>/dev/null && ! command -v convert &>/dev/null; then
        log_warn "ImageMagick niet gevonden — geen fallbackwallpaper gegenereerd"
        return 0
    fi

    local magick_cmd="magick"
    command -v magick &>/dev/null || magick_cmd="convert"

    # Donkerblauw→paars gradient (Kingstra stijl)
    # shellcheck disable=SC2140 # ImageMagick-syntax kleur-kleur
    "$magick_cmd" -size 1920x1080 \
        gradient:"#1e1e2e"-"#313244" \
        -gravity center \
        "$out" 2>/dev/null && {
        log_ok "Fallbackwallpaper gegenereerd: $out"

        # Sla op als huidige wallpaper zodat init iets heeft
        local state_dir="${XDG_CACHE_HOME:-$HOME/.cache}/kingstra"
        mkdir -p "$state_dir"
        echo "$out" > "$state_dir/last-wallpaper"
        echo "static"  > "$state_dir/wallpaper-mode"
        _phase09_sync_skwd_cache "$out" "static"
        _phase09_apply_initial_wallpaper "$out"
    } || log_warn "Kon geen fallbackwallpaper genereren"
}

_phase09_set_initial_wallpaper_from_dir() {
    local wdir="$1"
    local first_wallpaper

    first_wallpaper="$(find "$wdir" -maxdepth 2 -type f \
        \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) \
        2>/dev/null | sort | head -1)"

    if [[ -z "$first_wallpaper" || ! -f "$first_wallpaper" ]]; then
        return 0
    fi

    local state_dir="${XDG_CACHE_HOME:-$HOME/.cache}/kingstra"
    mkdir -p "$state_dir"
    echo "$first_wallpaper" > "$state_dir/last-wallpaper"
    echo "static" > "$state_dir/wallpaper-mode"
    _phase09_sync_skwd_cache "$first_wallpaper" "static"
    log_ok "Eerste wallpaper ingesteld in state: $first_wallpaper"
    _phase09_apply_initial_wallpaper "$first_wallpaper"
}

_phase09_sync_skwd_cache() {
    local wallpaper="$1"
    local mode="${2:-static}"
    [[ -n "$wallpaper" && -f "$wallpaper" ]] || return 0

    local skwd_cache="${XDG_CACHE_HOME:-$HOME/.cache}/skwd-wall"
    mkdir -p "$skwd_cache"

    printf '%s\n' "$wallpaper" > "$skwd_cache/current_wallpaper"
    printf '%s\n' "$wallpaper" > "$skwd_cache/current-wallpaper"
    printf '%s\n' "$wallpaper" > "$skwd_cache/last_wallpaper"
    printf '%s\n' "$wallpaper" > "$skwd_cache/last-wallpaper"

    if command -v jq &>/dev/null; then
        jq -n --arg path "$wallpaper" --arg type "$mode" \
            '{"path":$path,"type":$type}' \
            > "$skwd_cache/last-wallpaper.json" 2>/dev/null || true
    fi
}

_phase09_apply_initial_wallpaper() {
    local wallpaper="$1"

    [[ -f "$wallpaper" ]] || return 0

    if command -v kingstra-wallpaper &>/dev/null; then
        kingstra-wallpaper set "$wallpaper" >/dev/null 2>&1 && {
            log_ok "Standaard wallpaper toegepast: $wallpaper"
            return 0
        }
    fi

    log_warn "Kon standaard wallpaper niet direct toepassen; Hyprland autostart herstelt hem later"
}
