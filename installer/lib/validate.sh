#!/usr/bin/env bash
# =============================================================================
# validate.sh — Validatiechecks na installatie
# =============================================================================
# In dry-run modus worden bestand/map/symlink-checks overgeslagen
# (die bestaan immers nog niet). Commando-checks lopen altijd door.
# =============================================================================

VALIDATE_ERRORS=0

# Controleer of een commando beschikbaar is (altijd actief, ook in dry-run)
validate_cmd() {
    local cmd="$1"
    local label="${2:-$cmd}"
    if has_cmd "$cmd"; then
        log_ok "Gevonden: $label"
    else
        log_error "Niet gevonden: $label"
        (( VALIDATE_ERRORS++ )) || true
    fi
}

# Controleer of een bestand bestaat (overgeslagen in dry-run)
validate_file() {
    local file="$1"
    local label="${2:-$file}"
    if "${DRY_RUN:-false}"; then
        log_dry "Bestand-check overgeslagen (dry-run): $label"
        return 0
    fi
    if [[ -f "$file" || -L "$file" ]]; then
        log_ok "Aanwezig: $label"
    else
        log_error "Ontbreekt: $label"
        (( VALIDATE_ERRORS++ )) || true
    fi
}

# Controleer of een map bestaat (overgeslagen in dry-run)
validate_dir() {
    local dir="$1"
    local label="${2:-$dir}"
    if "${DRY_RUN:-false}"; then
        log_dry "Map-check overgeslagen (dry-run): $label"
        return 0
    fi
    if [[ -d "$dir" ]]; then
        log_ok "Map aanwezig: $label"
    else
        log_error "Map ontbreekt: $label"
        (( VALIDATE_ERRORS++ )) || true
    fi
}

# Controleer of een symlink correct wijst (overgeslagen in dry-run)
validate_link() {
    local link="$1"
    local expected_target="$2"
    if "${DRY_RUN:-false}"; then
        log_dry "Symlink-check overgeslagen (dry-run): $link"
        return 0
    fi
    if [[ -L "$link" ]]; then
        local actual_target
        actual_target="$(readlink "$link")"
        if [[ "$actual_target" == "$expected_target" ]]; then
            log_ok "Symlink correct: $link"
        else
            log_error "Symlink wijst verkeerd: $link → $actual_target (verwacht: $expected_target)"
            (( VALIDATE_ERRORS++ )) || true
        fi
    else
        log_error "Geen symlink: $link"
        (( VALIDATE_ERRORS++ )) || true
    fi
}

# Rapporteer totaal van validatiefouten
validate_report() {
    echo ""
    if "${DRY_RUN:-false}"; then
        log_info "Dry-run: validatierapport overgeslagen (geen echte wijzigingen gemaakt)."
        return 0
    fi
    if [[ $VALIDATE_ERRORS -eq 0 ]]; then
        log_ok "Validatie geslaagd — geen fouten gevonden."
    else
        log_error "Validatie mislukt — $VALIDATE_ERRORS fout(en) gevonden."
        return 1
    fi
}
