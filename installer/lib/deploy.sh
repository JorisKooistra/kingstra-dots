#!/usr/bin/env bash
# =============================================================================
# deploy.sh — Configuratiebestanden deployen via symlinks
# =============================================================================

# Maak een symlink van src naar dest.
# Maakt eerst een back-up als dest al bestaat.
# Idempotent: als dest al correct linkt naar src, wordt niets gedaan.
deploy_link() {
    local src="$1"
    local dest="$2"

    if [[ ! -e "$src" ]]; then
        log_warn "Bronbestand bestaat niet: $src — symlink overgeslagen"
        return 0
    fi

    # Idempotent: als symlink al correct is, skip
    if [[ -L "$dest" ]] && [[ "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
        log_ok "Symlink al correct: $dest → $src"
        return 0
    fi

    # Back-up van bestaand bestand/map/symlink
    backup_path "$dest"

    if "${DRY_RUN:-false}"; then
        log_dry "Symlink: $dest → $src"
        return 0
    fi

    # Verwijder bestaande dest (al geback-upt)
    if [[ -L "$dest" || -e "$dest" ]]; then
        rm -rf "$dest"
    fi

    ensure_dir "$(dirname "$dest")"
    ln -s "$src" "$dest"
    log_ok "Symlink aangemaakt: $dest → $src"
}

# Kopieer src naar dest (voor gevallen waar symlinks niet werken)
deploy_copy() {
    local src="$1"
    local dest="$2"

    if [[ ! -e "$src" ]]; then
        log_warn "Bronbestand bestaat niet: $src — kopie overgeslagen"
        return 0
    fi

    backup_path "$dest"

    if "${DRY_RUN:-false}"; then
        log_dry "Kopie: $src → $dest"
        return 0
    fi

    ensure_dir "$(dirname "$dest")"
    cp -r "$src" "$dest"
    log_ok "Gekopieerd: $src → $dest"
}

# Deploy een hele config-submap als symlink
# bijv. deploy_config "hypr" → ~/.config/hypr → $REPO_ROOT/config/hypr
deploy_config() {
    local name="$1"
    local src="$REPO_ROOT/config/$name"
    local dest="$HOME/.config/$name"
    deploy_link "$src" "$dest"
}

# Deploy meerdere config-submappen tegelijk
deploy_configs() {
    for name in "$@"; do
        deploy_config "$name"
    done
}

# Deploy .default-bestanden als de werkelijke bestanden nog niet bestaan.
# Zoekt recursief naar *.default in de opgegeven directory.
# Bestaande user-state wordt NOOIT overschreven.
deploy_defaults() {
    local dir="$1"

    if [[ ! -d "$dir" ]]; then
        log_warn "Directory bestaat niet: $dir — defaults overgeslagen"
        return 0
    fi

    while IFS= read -r -d '' default_file; do
        local target="${default_file%.default}"

        if [[ -e "$target" ]]; then
            log_ok "User-state behouden: $target"
            continue
        fi

        if "${DRY_RUN:-false}"; then
            log_dry "Default kopiëren: $default_file → $target"
            continue
        fi

        cp "$default_file" "$target"
        log_ok "Default gekopieerd: $target"
    done < <(find "$dir" -name '*.default' -print0)
}

# Deploy vanuit files.txt manifest
# Formaat: src_relatief_aan_repo|dest_absoluut_of_relatief_aan_HOME
deploy_from_manifest() {
    local manifest_file="$1"

    if [[ ! -f "$manifest_file" ]]; then
        log_warn "Files-manifest niet gevonden: $manifest_file"
        return 0
    fi

    while IFS='|' read -r src dest || [[ -n "$src" ]]; do
        [[ -z "$src" || "$src" == \#* ]] && continue

        # Expand ~ in dest
        dest="${dest/#\~/$HOME}"

        local abs_src="$REPO_ROOT/$src"
        deploy_link "$abs_src" "$dest"
    done < "$manifest_file"
}
