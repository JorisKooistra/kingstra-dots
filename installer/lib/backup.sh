#!/usr/bin/env bash
# =============================================================================
# backup.sh — Back-up van bestaande configuratiebestanden
# =============================================================================

BACKUP_BASE="${XDG_DATA_HOME:-$HOME/.local/share}/kingstra/backups"
BACKUP_DIR=""

# Alle bekende installatiedestinaties — worden pre-flight geback-upt
_BACKUP_KNOWN_PATHS=(
    "$HOME/.config/com.ml4w.hyprlandsettings"
    "$HOME/.config/hypr"
    "$HOME/.config/quickshell"
    "$HOME/.config/kitty"
    "$HOME/.config/zsh"
    "$HOME/.config/matugen"
    "$HOME/.config/qt6ct"
    "$HOME/.config/swaync"
    "$HOME/.config/walker"
    "$HOME/.config/waybar"
    "$HOME/.config/ml4w"
    "$HOME/.config/ml4w-dotfiles-settings"
    "$HOME/.config/waypaper"
    "$HOME/.config/wlogout"
    "$HOME/.config/nwg-dock-hyprland"
    "$HOME/.config/rofi"
    "$HOME/.config/wallust"
    "$HOME/.config/kingstra"
    "$HOME/.config/skwd-wall"
    "$HOME/.config/xdg-desktop-portal"
    "$HOME/.config/gtk-3.0"
    "$HOME/.config/gtk-4.0"
    "$HOME/.config/systemd/user"
    "$HOME/.config/yazi"
    "$HOME/.config/hypridle"
    "$HOME/.config/hyprlock"
    "$HOME/.config/fastfetch"
    "$HOME/.config/cava"
    "$HOME/.config/btop"
    "$HOME/.config/wallpaper"
    "$HOME/.gtkrc-2.0"
    "$HOME/.zshenv"
    "$HOME/.local/bin/kingstra-theme-apply"
    "$HOME/.local/bin/kingstra-session-start"
    "$HOME/.local/bin/kingstra-wallpaper"
)

backup_init() {
    BACKUP_DIR="$BACKUP_BASE/$(date '+%Y%m%d_%H%M%S')"
    export BACKUP_DIR
    if ! "${DRY_RUN:-false}"; then
        mkdir -p "$BACKUP_DIR"
    fi
}

# ---------------------------------------------------------------------------
# Pre-flight: back-up alle bekende dotfile-locaties vóór installatie start
# ---------------------------------------------------------------------------
backup_preflight() {
    local found=()

    for path in "${_BACKUP_KNOWN_PATHS[@]}"; do
        [[ -e "$path" || -L "$path" ]] && found+=("$path")
    done

    if [[ ${#found[@]} -eq 0 ]]; then
        log_info "Geen bestaande dotfiles gevonden — back-up overgeslagen."
        return 0
    fi

    # Zorg dat BACKUP_DIR al gezet is (backup_init moet al zijn aangeroepen)
    log_info "Bestaande dotfiles gevonden — back-up maken naar:"
    log_info "  $BACKUP_DIR"
    echo ""

    for path in "${found[@]}"; do
        backup_path "$path"
    done

    echo ""
    log_ok "${#found[@]} locatie(s) geback-upt naar: $BACKUP_DIR"
    log_info "Herstellen: cp -r \"$BACKUP_DIR/<pad>\" ~/<pad>"
    echo ""
}

# Back-up van één bestand of map maken
backup_path() {
    local src="$1"

    if [[ ! -e "$src" && ! -L "$src" ]]; then
        return 0  # Niets te back-uppen
    fi

    if [[ -z "$BACKUP_DIR" ]]; then
        backup_init
    fi

    # Relatief pad bepalen t.o.v. $HOME
    local rel_path="${src#"$HOME/"}"
    local dest="$BACKUP_DIR/$rel_path"

    if "${DRY_RUN:-false}"; then
        log_dry "Back-up: $src → $dest"
        return 0
    fi

    mkdir -p "$(dirname "$dest")"

    if [[ -L "$src" ]]; then
        # Symlink: kopieer de link zelf
        cp -P "$src" "$dest"
        log_step "Back-up symlink: $src"
    elif [[ -d "$src" ]]; then
        cp -r "$src" "$dest"
        log_step "Back-up map: $src"
    else
        cp "$src" "$dest"
        log_step "Back-up bestand: $src"
    fi
}

# Back-up van meerdere paden tegelijk
backup_paths() {
    for path in "$@"; do
        backup_path "$path"
    done
}
