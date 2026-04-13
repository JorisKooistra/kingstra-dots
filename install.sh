#!/usr/bin/env bash
# =============================================================================
# kingstra-dots — Installer
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT
export PATH="$HOME/.local/bin:$PATH"

# ---------------------------------------------------------------------------
# Bibliotheekbestanden inladen
# ---------------------------------------------------------------------------
for lib in "$REPO_ROOT"/installer/lib/*.sh; do
    # shellcheck source=/dev/null
    source "$lib"
done

# ---------------------------------------------------------------------------
# Standaardwaarden
# ---------------------------------------------------------------------------
DRY_RUN=false
OVERRIDE_FILE=""    # Optioneel override-bestand na auto-detectie
SELECTED_PHASE=""
FROM_PHASE=""
SKIP_CONFIRM=false
INSTALL_VERBOSE_COMMANDS="${INSTALL_VERBOSE_COMMANDS:-false}"

PHASES_DIR="$REPO_ROOT/installer/phases"

ALL_PHASES=(
    01_project_base
    02_shell_terminal
    03_hypr_core
    04_bindings
    05_ui_quickshell
    06_notifications
    07_launcher
    08_theming
    09_wallpaper
    10_session
    11_apps_tools
    12_network_resume_fixes
    13_monitoring
    14_profiles
    15_finalize
)

# ---------------------------------------------------------------------------
# Argumenten verwerken
# ---------------------------------------------------------------------------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --phase)
                SELECTED_PHASE="$2"
                shift 2
                ;;
            --from-phase)
                FROM_PHASE="$2"
                shift 2
                ;;
            --override)
                OVERRIDE_FILE="$2"
                shift 2
                ;;
            --yes|-y)
                SKIP_CONFIRM=true
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                log_error "Onbekend argument: $1"
                usage
                exit 1
                ;;
        esac
    done

    export DRY_RUN OVERRIDE_FILE SELECTED_PHASE FROM_PHASE SKIP_CONFIRM INSTALL_VERBOSE_COMMANDS
}

usage() {
    cat <<EOF
Gebruik: ./install.sh [opties]

Opties:
  (geen)               Alle fases uitvoeren — hardware wordt automatisch gedetecteerd
  --dry-run            Laat zien wat er zou gebeuren zonder wijzigingen
  --phase FASE         Voer alleen één fase uit (bijv. 01_project_base)
  --from-phase FASE    Start vanaf een specifieke fase
  --override BESTAND   Overschrijf gedetecteerde feature-flags met een bestand
  --yes, -y            Bevestigingsvragen overslaan
  --help, -h           Dit helpbericht tonen

Voorbeelden:
  ./install.sh
  ./install.sh --dry-run
  ./install.sh --phase 01_project_base
  ./install.sh --from-phase 03_hypr_core
  ./install.sh --override my-overrides.conf --yes

Override-bestand formaat (optioneel, overschrijft auto-detectie):
  ENABLE_FINGERPRINT=false
  ENABLE_TABLET_MODE=true
  ENABLE_VIDEO_WALLPAPER=false
  ENABLE_SPICETIFY=true
EOF
}

# ---------------------------------------------------------------------------
# Fases uitvoeren
# ---------------------------------------------------------------------------
resolve_phases() {
    local phases_to_run=()

    if [[ -n "$SELECTED_PHASE" ]]; then
        phases_to_run=("$SELECTED_PHASE")
    elif [[ -n "$FROM_PHASE" ]]; then
        local found=false
        for phase in "${ALL_PHASES[@]}"; do
            if [[ "$phase" == "$FROM_PHASE" ]]; then
                found=true
            fi
            if $found; then
                phases_to_run+=("$phase")
            fi
        done
        if ! $found; then
            log_error "Fase '$FROM_PHASE' niet gevonden."
            exit 1
        fi
    else
        phases_to_run=("${ALL_PHASES[@]}")
    fi

    echo "${phases_to_run[@]}"
}

run_phases() {
    local -a phases
    read -r -a phases <<< "$(resolve_phases)"
    local total="${#phases[@]}"
    local idx=0

    for phase in "${phases[@]}"; do
        idx=$((idx + 1))
        local phase_file="$PHASES_DIR/${phase}.sh"
        if [[ ! -f "$phase_file" ]]; then
            log_warn "Fasescript niet gevonden: $phase_file — overgeslagen"
            continue
        fi

        set_phase_progress "$total" "$idx"
        log_phase "$phase" "$idx" "$total"
        # shellcheck source=/dev/null
        source "$phase_file"

        if declare -f "phase_run" > /dev/null; then
            phase_run
            unset -f phase_run
        else
            log_warn "Fase '$phase' heeft geen phase_run() functie."
        fi
    done
}

# ---------------------------------------------------------------------------
# Hoofdstroom
# ---------------------------------------------------------------------------
main() {
    parse_args "$@"

    log_init
    detect_system

    # Optioneel: overschrijf gedetecteerde waarden met een gebruikersbestand
    if [[ -n "$OVERRIDE_FILE" ]]; then
        apply_overrides "$OVERRIDE_FILE"
    fi

    # Back-upmap aanmaken met vaste timestamp voor de hele sessie
    backup_init

    print_banner
    print_system_info

    if ! $SKIP_CONFIRM && ! $DRY_RUN; then
        prompt_confirm "Doorgaan met installatie?" || { log_info "Installatie geannuleerd."; exit 0; }
    fi

    if $DRY_RUN; then
        log_warn "DRY-RUN modus actief — geen wijzigingen worden doorgevoerd."
    elif command -v sudo &>/dev/null && [[ -t 0 ]]; then
        log_step "Sudo-sessie valideren..."
        sudo -v || { log_error "Sudo-validatie mislukt."; exit 1; }
    fi

    # Pre-flight: back-up alle bestaande dotfiles vóór de eerste fase
    backup_preflight

    run_phases

    print_summary
}

main "$@"
