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
