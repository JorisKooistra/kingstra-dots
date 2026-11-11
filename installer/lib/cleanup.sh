#!/usr/bin/env bash
# =============================================================================
# cleanup.sh — Verwijder bekende conflicterende / verouderde bestanden
# =============================================================================

cleanup_legacy_paths() {
    local manifest="$REPO_ROOT/manifest/cleanup-paths.txt"

    if [[ ! -f "$manifest" ]]; then
        log_warn "Cleanup-manifest niet gevonden: $manifest"
        return 0
    fi

    local found=0

    while IFS='|' read -r raw_path reason; do
        [[ -z "$raw_path" || "$raw_path" == \#* ]] && continue

        local path="${raw_path/#\~/$HOME}"

        if [[ -e "$path" || -L "$path" ]]; then
            found=$((found + 1))
            if "${DRY_RUN:-false}"; then
                log_dry "Zou verwijderen: $path ($reason)"
            else
                rm -f "$path"
                log_ok "Verwijderd: $(basename "$path")"
                log_info "  Reden: $reason"
            fi
        fi
    done < "$manifest"

    if [[ $found -eq 0 ]]; then
        log_info "Geen conflicterende bestanden gevonden."
    fi
}

# Kapotte symlinks die naar de repo wijzen, ruimen we op: dat zijn
# koppelingen naar configmappen die uit kingstra-dots zijn gehaald (zoals
# config/swaync). Alleen links die écht dood zijn en écht in de repo
# wezen; verder raken we niets aan.
cleanup_dead_repo_links() {
    local repo="${REPO_ROOT:?}"
    local dir link target found=0

    for dir in "$HOME" "${XDG_CONFIG_HOME:-$HOME/.config}" "$HOME/.local/bin" \
               "${XDG_DATA_HOME:-$HOME/.local/share}/applications"; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r -d '' link; do
            target="$(readlink "$link")" || continue
            [[ "$target" == "$repo"/* ]] || continue
            [[ -e "$link" ]] && continue
            found=$((found + 1))
            if "${DRY_RUN:-false}"; then
                log_dry "Zou kapotte koppeling weghalen: $link -> $target"
            else
                rm -f -- "$link"
                log_ok "Kapotte koppeling weg: ${link/#$HOME/\~}"
            fi
        done < <(find "$dir" -maxdepth 1 -type l -print0 2>/dev/null)
    done

    (( found == 0 )) && log_info "Geen kapotte koppelingen naar de repo."
    return 0
}
