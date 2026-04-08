#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — Kingstra-dots eenmalige installatie
# =============================================================================
# Gebruik:
#   bash <(curl -fsSL https://raw.githubusercontent.com/JorisKooistra/kingstra-dots/main/bootstrap.sh)
#
# Of met opties doorgeven:
#   bash <(curl -fsSL https://raw.githubusercontent.com/JorisKooistra/kingstra-dots/main/bootstrap.sh) --dry-run
# =============================================================================
set -euo pipefail

REPO_URL="https://github.com/JorisKooistra/kingstra-dots.git"
REPO_DIR="${KINGSTRA_DIR:-$HOME/kingstra-dots}"
BOLD='\033[1m'
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
RESET='\033[0m'

_log()  { printf "${BOLD}[kingstra]${RESET} %s\n" "$*"; }
_ok()   { printf "${GREEN}[kingstra]${RESET} %s\n" "$*"; }
_warn() { printf "${YELLOW}[kingstra] WARN:${RESET} %s\n" "$*" >&2; }
_die()  { printf "${RED}[kingstra] FOUT:${RESET} %s\n" "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Vereisten controleren
# ---------------------------------------------------------------------------
_log "Vereisten controleren..."

[[ -f /etc/arch-release ]] || _die "Alleen Arch Linux wordt ondersteund."

command -v git  &>/dev/null || _die "git niet gevonden. Installeer met: sudo pacman -S git"
command -v curl &>/dev/null || _die "curl niet gevonden. Installeer met: sudo pacman -S curl"
command -v bash &>/dev/null || _die "bash niet gevonden."

# bash 4.4+
if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4) )); then
    _die "bash 4.4+ vereist (huidig: $BASH_VERSION)"
fi

# AUR-helper
if command -v yay &>/dev/null; then
    _ok "AUR-helper gevonden: yay"
elif command -v paru &>/dev/null; then
    _ok "AUR-helper gevonden: paru"
else
    _warn "Geen AUR-helper gevonden (yay/paru)."
    _warn "AUR-pakketten kunnen niet automatisch worden geïnstalleerd."
    _warn "Installeer yay: https://github.com/Jguer/yay#installation"
    read -r -p "Toch doorgaan? [j/N] " antwoord
    [[ "${antwoord,,}" == "j" ]] || { _log "Geannuleerd."; exit 0; }
fi

# ---------------------------------------------------------------------------
# Repository klonen of bijwerken
# ---------------------------------------------------------------------------
if [[ -d "$REPO_DIR/.git" ]]; then
    _log "Repo bestaat al — bijwerken: $REPO_DIR"
    git -C "$REPO_DIR" fetch --quiet origin main 2>/dev/null || true
    git -C "$REPO_DIR" reset --hard origin/main 2>/dev/null && \
        _ok "Repo bijgewerkt" || \
        _warn "Bijwerken mislukt — doorgaan met huidige versie"
elif [[ -d "$REPO_DIR" ]]; then
    _warn "Map $REPO_DIR bestaat maar is geen git-repo — herklonen"
    mv "$REPO_DIR" "${REPO_DIR}.bak.$(date +%s)"
    git clone --depth=1 "$REPO_URL" "$REPO_DIR"
    _ok "Repo gekloond (oude map hernoemd naar .bak)"
else
    _log "Repo klonen naar: $REPO_DIR"
    git clone --depth=1 "$REPO_URL" "$REPO_DIR"
    _ok "Repo gekloond"
fi

# ---------------------------------------------------------------------------
# Installer uitvoeren
# ---------------------------------------------------------------------------
_ok "Installer starten..."
printf '\n'

exec bash "$REPO_DIR/install.sh" "$@"
