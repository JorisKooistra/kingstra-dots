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

# Geef alleen de exitstatus en parseruitvoer terug; callers bepalen zelf hoe
# een fout wordt gelogd of afgehandeld.
lua_file_syntax_check() {
    local file="$1"

    if has_cmd luac; then
        luac -p "$file"
        return $?
    elif has_cmd lua; then
        KINGSTRA_VALIDATE_LUA_FILE="$file" lua -e '
            local path = os.getenv("KINGSTRA_VALIDATE_LUA_FILE")
            local chunk, err = loadfile(path)
            if not chunk then
                io.stderr:write(err, "\n")
                os.exit(1)
            end
        '
        return $?
    fi

    printf 'luac/lua ontbreekt; Lua-syntaxcheck niet mogelijk\n' >&2
    return 127
}

# Controleer of een Lua-bestand bestaat en syntactisch geldig is.
validate_lua_file() {
    local file="$1"
    local label="${2:-$file}"

    if "${DRY_RUN:-false}"; then
        log_dry "Lua-syntaxcheck overgeslagen (dry-run): $label"
        return 0
    fi

    if [[ ! -f "$file" && ! -L "$file" ]]; then
        log_error "Ontbreekt: $label"
        (( VALIDATE_ERRORS++ )) || true
        return 0
    fi

    local output=""
    if output="$(lua_file_syntax_check "$file" 2>&1)"; then
        log_ok "Geldige Lua: $label"
        return 0
    fi

    log_error "Ongeldige Lua: $label"
    [[ -n "$output" ]] && log_error "  $output"
    (( VALIDATE_ERRORS++ )) || true
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
# validate_link <link> <verwacht_doel> [label]
# Als expected_target leeg is, wordt alleen gecontroleerd of het een symlink is.
validate_link() {
    local link="$1"
    local expected_target="${2:-}"
    local label="${3:-$link}"
    if "${DRY_RUN:-false}"; then
        log_dry "Symlink-check overgeslagen (dry-run): $label"
        return 0
    fi
    if [[ -L "$link" ]]; then
        if [[ -z "$expected_target" ]]; then
            log_ok "Symlink aanwezig: $label"
            return 0
        fi
        local actual_target
        actual_target="$(readlink "$link")"
        if [[ "$actual_target" == "$expected_target" ]]; then
            log_ok "Symlink correct: $label"
        else
            log_error "Symlink wijst verkeerd: $label → $actual_target (verwacht: $expected_target)"
            (( VALIDATE_ERRORS++ )) || true
        fi
    else
        log_error "Geen symlink: $label"
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
