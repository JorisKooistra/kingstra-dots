#!/usr/bin/env bash
# =============================================================================
# backup.sh — Back-up van bestaande configuratiebestanden
# =============================================================================

BACKUP_BASE="${XDG_DATA_HOME:-$HOME/.local/share}/kingstra/backups"
BACKUP_DIR=""

backup_init() {
    BACKUP_DIR="$BACKUP_BASE/$(date '+%Y%m%d_%H%M%S')"
    export BACKUP_DIR
    if ! "${DRY_RUN:-false}"; then
        mkdir -p "$BACKUP_DIR"
        log_info "Back-upmap aangemaakt: $BACKUP_DIR"
    else
        log_dry "Back-upmap zou aangemaakt worden: $BACKUP_DIR"
    fi
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
