#!/usr/bin/env bash
# =============================================================================
# Fase 09 — Wallpapermodule
# =============================================================================
# Doel:
#   - Hyprpaper (statisch) en optioneel mpvpaper (video) installeren
#   - config/hyprpaper deployen
#   - kingstra-wallpaper orchestrator deployen naar ~/.local/bin/
#   - Verbeterde wallpaper-init.sh deployen (vervangt fase 3-versie)
#   - Wallpaper-map aanmaken als die nog niet bestaat
#   - Voorbeeldwallpaper plaatsen als map leeg is (gegenereerde kleur-gradient)
# =============================================================================

phase_run() {
    log_step "Wallpaper-pakketten installeren..."
    aur_install awww                    # wallpaper daemon (vervangt hyprpaper)
    pacman_install imagemagick          # voor gradient-fallback + manipulatie
    pacman_install ffmpeg               # voor videothumbnails / -verwerking
    pacman_install sqlite               # walker/history dep, ook nuttig voor indexer
    pacman_install inotify-tools        # voor live-reloadwatcher (optioneel)
    pacman_install chafa                # ASCII/pixel-preview in fzf picker

    log_step "skwd-wall installeren..."
    _phase09_install_skwd_wall

    log_step "skwd-wall config aanmaken..."
    _phase09_write_skwd_wall_config

    log_step "Videowallpaper-pakket installeren (mpvpaper)..."
    _phase09_install_mpvpaper

    log_step "Wallpaper-orchestrator deployen..."
    _phase09_deploy_orchestrator

    log_step "Wallpaper-map aanmaken..."
    _phase09_ensure_wallpaper_dir

    log_step "Fase 09 valideren..."
    validate_cmd awww
    validate_dir  "$HOME/.config/skwd-wall"                "skwd-wall"
    validate_file "$HOME/.config/skwd-wall/daemon.qml"     "skwd-wall/daemon.qml"
    validate_file "$HOME/.config/skwd-wall/config.json"    "skwd-wall/config.json"
    validate_file "$HOME/.local/bin/kingstra-wallpaper"    "kingstra-wallpaper"
    validate_dir  "$HOME/Pictures/Wallpapers"              "Pictures/Wallpapers"
    validate_report

    log_ok "Fase 09 voltooid — Wallpapermodule actief."
    log_info "Wallpaper instellen: kingstra-wallpaper set <bestand>"
    log_info "Interactieve kiezer: kingstra-wallpaper pick"
    log_info "Willekeurig:        kingstra-wallpaper random"
    log_info "Videowallpaper:     kingstra-wallpaper video <bestand>"
}

# ---------------------------------------------------------------------------

_phase09_install_skwd_wall() {
    local dest="$HOME/.config/skwd-wall"

    if "${DRY_RUN:-false}"; then
        log_dry "skwd-wall zou worden gecloned naar: $dest"
        return 0
    fi

    if [[ -d "$dest/.git" ]]; then
        log_info "skwd-wall al aanwezig — updaten..."
        git -C "$dest" pull --ff-only 2>/dev/null && \
            log_ok "skwd-wall bijgewerkt" || \
            log_warn "skwd-wall update mislukt — bestaande versie behouden"
        return 0
    fi

    git clone --depth=1 https://github.com/liixini/skwd-wall "$dest" && \
        log_ok "skwd-wall gecloned naar: $dest" || \
        log_warn "skwd-wall klonen mislukt — controleer internetverbinding"
}

_phase09_write_skwd_wall_config() {
    local config_dest="$HOME/.config/skwd-wall/config.json"

    if "${DRY_RUN:-false}"; then
        log_dry "skwd-wall config.json zou worden aangemaakt: $config_dest"
        return 0
    fi

    if [[ -f "$config_dest" ]]; then
        log_info "skwd-wall config.json bestaat al — niet overschreven"
        return 0
    fi

    if [[ ! -d "$(dirname "$config_dest")" ]]; then
        log_warn "skwd-wall map bestaat niet — config.json overgeslagen"
        return 0
    fi

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
        "matugen": true,
        "ollama": false,
        "steam": false,
        "wallhaven": false
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
        { "name": "yazi", "template": "yazi-theme.toml", "output": "~/.config/yazi/theme.toml" },
        { "name": "omp", "reload": "~/.config/skwd-wall/scripts/reload-omp.sh" }
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
    "performance": {
        "imageOptimizePreset": "balanced",
        "imageOptimizeResolution": "2k"
    }
}
EOF
    log_ok "skwd-wall config.json aangemaakt: $config_dest"
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

    if "${DRY_RUN:-false}"; then
        log_dry "Orchestrator zou worden gedeployed: $script_dest"
        return 0
    fi

    ensure_dir "$HOME/.local/bin"
    deploy_link "$script_src" "$script_dest"
    chmod +x "$script_src"
    log_ok "Orchestrator beschikbaar als: kingstra-wallpaper"
}

_phase09_ensure_wallpaper_dir() {
    local wdir="$HOME/Pictures/Wallpapers"

    if "${DRY_RUN:-false}"; then
        log_dry "Wallpaper-map zou worden aangemaakt: $wdir"
        return 0
    fi

    if [[ ! -d "$wdir" ]]; then
        mkdir -p "$wdir"
        log_ok "Wallpaper-map aangemaakt: $wdir"
    else
        log_info "Wallpaper-map bestaat al: $wdir"
    fi

    # Genereer een fallbackwallpaper als de map leeg is
    local count
    count="$(find "$wdir" -maxdepth 2 -type f \
        \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) \
        2>/dev/null | wc -l)"

    if [[ "$count" -eq 0 ]]; then
        _phase09_generate_fallback_wallpaper "$wdir"
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
    } || log_warn "Kon geen fallbackwallpaper genereren"
}
