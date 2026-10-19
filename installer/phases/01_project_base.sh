#!/usr/bin/env bash
# =============================================================================
# Fase 01 — Projectskelet en installerfundering
# =============================================================================
# Doel:
#   - Repo-structuur valideren
#   - Loginfrastructuur opzetten
#   - Back-up initialiseren
#   - Testbestanden deployen om mechanisme te bewijzen
#   - Basisvereisten controleren
# =============================================================================

phase_run() {
    log_step "Basisvereisten controleren..."
    _phase01_check_requirements

    log_step "Back-upmechanisme initialiseren..."
    backup_init

    log_step "Projectstructuur valideren..."
    _phase01_validate_structure

    log_step "Testdeploy uitvoeren..."
    _phase01_test_deploy

    log_step "AUR-builds zonder debugpakketten..."
    _phase01_makepkg_no_debug

    log_ok "Fase 01 voltooid — projectfundering staat."
}

# ---------------------------------------------------------------------------

# Arch zet OPTIONS=(debug) standaard aan, waardoor elke AUR-build ook een
# <pakket>-debug installeert dat bij elke update mee moet. De gebruikersconfig
# van makepkg wordt na /etc/makepkg.conf ingelezen, dus dit wint.
_phase01_makepkg_no_debug() {
    local conf="${XDG_CONFIG_HOME:-$HOME/.config}/pacman/makepkg.conf"
    if [[ -f "$conf" ]] && grep -q '!debug' "$conf"; then
        log_info "makepkg bouwt al zonder debugpakketten"
        return 0
    fi
    if "${DRY_RUN:-false}"; then
        log_dry "OPTIONS+=(!debug) toevoegen aan $conf"
        return 0
    fi
    mkdir -p "$(dirname "$conf")"
    printf '\n# kingstra-dots: geen losse -debug-pakketten bij AUR-builds\nOPTIONS+=(!debug)\n' >> "$conf"
    log_ok "makepkg bouwt voortaan zonder debugpakketten ($conf)"
}

_phase01_check_requirements() {
    # Verplicht: Arch Linux
    if [[ "$DETECTED_DISTRO" != "arch" ]]; then
        log_error "Arch Linux is vereist. Gedetecteerde distro: $DETECTED_DISTRO"
        exit 1
    fi

    # Verplicht: bash 4.4+
    if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4) )); then
        log_error "Bash 4.4 of hoger is vereist. Huidige versie: ${BASH_VERSION}"
        exit 1
    fi

    # Verplicht: git
    if ! has_cmd git; then
        log_error "git is niet gevonden. Installeer git en probeer opnieuw."
        exit 1
    fi

    # Aanbevolen: AUR-helper
    if [[ -z "${AUR_HELPER:-}" ]]; then
        log_warn "Geen AUR-helper (yay/paru) gevonden."
        log_warn "AUR-pakketten kunnen niet automatisch worden geïnstalleerd."
        if ! prompt_confirm "Doorgaan zonder AUR-helper?"; then
            log_info "Installatie gestopt. Installeer yay of paru en probeer opnieuw."
            exit 0
        fi
    fi

    log_ok "Basisvereisten in orde."
}

_phase01_validate_structure() {
    local -a required_dirs=(
        "$REPO_ROOT/installer/lib"
        "$REPO_ROOT/installer/phases"
        "$REPO_ROOT/installer/profiles"
        "$REPO_ROOT/manifest/packages"
        "$REPO_ROOT/config"
        "$REPO_ROOT/assets"
        "$REPO_ROOT/docs"
        "$REPO_ROOT/tests"
    )

    local missing=0
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log_error "Verwachte map ontbreekt: $dir"
            (( missing++ )) || true
        fi
    done

    if (( missing > 0 )); then
        log_error "$missing vereiste mappen ontbreken."
        exit 1
    fi

    log_ok "Projectstructuur compleet."
}

_phase01_test_deploy() {
    # Maak een testmarkerbestand aan in de log-map om te bewijzen dat
    # het deploymechanisme werkt, zonder echte config te raken.
    local marker_file="${XDG_DATA_HOME:-$HOME/.local/share}/kingstra/phase01.marker"

    if "${DRY_RUN:-false}"; then
        log_dry "Testmarker zou aangemaakt worden: $marker_file"
        return 0
    fi

    ensure_dir "$(dirname "$marker_file")"
    echo "fase01_ok=$(date '+%Y-%m-%d %H:%M:%S')" > "$marker_file"
    log_ok "Testmarker aangemaakt: $marker_file"
}
