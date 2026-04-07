#!/usr/bin/env bash
# =============================================================================
# common.sh — Gedeelde hulpfuncties
# =============================================================================

# Zorg dat REPO_ROOT altijd beschikbaar is
REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# ---------------------------------------------------------------------------
# Commando's uitvoeren (dry-run bewust)
# ---------------------------------------------------------------------------
run_cmd() {
    if "${DRY_RUN:-false}"; then
        log_dry "$*"
    else
        log_step "$ $*"
        "$@"
    fi
}

# ---------------------------------------------------------------------------
# Directories aanmaken
# ---------------------------------------------------------------------------
ensure_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        run_cmd mkdir -p "$dir"
    fi
}

# ---------------------------------------------------------------------------
# Controleer of een commando bestaat
# ---------------------------------------------------------------------------
has_cmd() {
    command -v "$1" &>/dev/null
}

# ---------------------------------------------------------------------------
# Veilig een bestand aanraken (dry-run bewust)
# ---------------------------------------------------------------------------
safe_touch() {
    local file="$1"
    ensure_dir "$(dirname "$file")"
    run_cmd touch "$file"
}

# ---------------------------------------------------------------------------
# Profiel inladen
# ---------------------------------------------------------------------------
load_profile() {
    local profile="${1:-default}"
    local profile_file="$REPO_ROOT/installer/profiles/${profile}.conf"

    if [[ -f "$profile_file" ]]; then
        log_info "Profiel ingeladen: $profile"
        # shellcheck source=/dev/null
        source "$profile_file"
    else
        log_warn "Profielbestand niet gevonden: $profile_file — standaardinstellingen worden gebruikt"
    fi
}
