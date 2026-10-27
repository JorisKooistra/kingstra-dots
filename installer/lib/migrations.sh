#!/usr/bin/env bash
# =============================================================================
# migrations.sh — Eenmalige migraties tussen versies
# =============================================================================
# Elke migratie is een los script in installer/migrations/ met een oplopend
# nummer: NNNN-korte-naam.sh. Het script definieert migration_run(); dat
# draait precies één keer per machine. Uitgevoerde migraties staan in
# ~/.local/state/kingstra/migrations (één naam per regel).
#
# Een verse installatie (nog geen install-complete marker) heeft geen oude
# stand om te migreren: dan worden alle migraties alleen als gedaan
# gemarkeerd.
#
# Een migratie die faalt wordt niet gemarkeerd en draait bij de volgende
# update opnieuw; de installer gaat wel door.
# =============================================================================

MIGRATIONS_DIR="${REPO_ROOT:-.}/installer/migrations"
MIGRATIONS_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/kingstra/migrations"

_migration_done() {
    [[ -f "$MIGRATIONS_STATE" ]] && grep -qxF "$1" "$MIGRATIONS_STATE"
}

_migration_mark() {
    mkdir -p "$(dirname "$MIGRATIONS_STATE")"
    printf '%s\n' "$1" >> "$MIGRATIONS_STATE"
}

run_pending_migrations() {
    local file name ran=0 failed=0
    local fresh=true
    [[ "${INSTALL_WAS_PRESENT:-false}" == "true" ]] && fresh=false

    [[ -d "$MIGRATIONS_DIR" ]] || return 0

    while IFS= read -r file; do
        name="$(basename "$file" .sh)"
        _migration_done "$name" && continue

        if "${DRY_RUN:-false}"; then
            log_dry "Migratie zou draaien: $name"
            continue
        fi
        if $fresh; then
            _migration_mark "$name"
            continue
        fi

        log_step "Migratie: $name"
        if (
            unset -f migration_run
            # shellcheck source=/dev/null
            source "$file"
            declare -f migration_run >/dev/null || exit 0
            migration_run
        ); then
            _migration_mark "$name"
            ran=$((ran + 1))
        else
            log_warn "Migratie $name mislukt; die draait bij de volgende update opnieuw."
            failed=$((failed + 1))
        fi
    done < <(find "$MIGRATIONS_DIR" -maxdepth 1 -type f -name '[0-9][0-9][0-9][0-9]-*.sh' | sort -V)

    if (( ran > 0 )); then
        log_ok "$ran migratie(s) uitgevoerd."
    fi
    (( failed == 0 ))
}
