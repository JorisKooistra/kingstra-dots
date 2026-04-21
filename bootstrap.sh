#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — Kingstra-dots install/update launcher
# =============================================================================
set -euo pipefail

REPO_URL="https://github.com/JorisKooistra/kingstra-dots.git"
REPO_REF="${KINGSTRA_REF:-}"
REPO_DIR="${KINGSTRA_DIR:-$HOME/kingstra-dots}"
DRY_RUN=false
BOOTSTRAP_SKIP_CONFIRM=false
BOOTSTRAP_HAS_OVERRIDE_ARG=false
INSTALL_MODE="new"
DOTFILES_INSTALLED=false
BOOTSTRAP_OVERRIDE_FILE=""

ENABLE_OPTIONAL_OFFICE=false
ENABLE_OPTIONAL_HEROIC=false
ENABLE_OPTIONAL_VLC=false

BOLD='\033[1m'
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
RESET='\033[0m'

_log()  { printf "${BOLD}[kingstra]${RESET} %s\n" "$*"; }
_ok()   { printf "${GREEN}[kingstra]${RESET} %s\n" "$*"; }
_warn() { printf "${YELLOW}[kingstra] WARN:${RESET} %s\n" "$*" >&2; }
_die()  { printf "${RED}[kingstra] FOUT:${RESET} %s\n" "$*" >&2; exit 1; }

_is_tty() {
    [[ -t 0 && -t 1 ]]
}

_clear_screen() {
    if _is_tty; then
        printf '\033c'
    fi
}

_print_banner() {
    cat <<'EOF'

   ██╗  ██╗██╗███╗   ██╗ ██████╗ ███████╗████████╗██████╗  █████╗
   ██║ ██╔╝██║████╗  ██║██╔════╝ ██╔════╝╚══██╔══╝██╔══██╗██╔══██╗
   █████╔╝ ██║██╔██╗ ██║██║  ███╗███████╗   ██║   ██████╔╝███████║
   ██╔═██╗ ██║██║╚██╗██║██║   ██║╚════██║   ██║   ██╔══██╗██╔══██║
   ██║  ██╗██║██║ ╚████║╚██████╔╝███████║   ██║   ██║  ██║██║  ██║
   ╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝
                dots — Arch Linux · Hyprland · Quickshell

EOF
}

_selected_extras_summary() {
    local -a extras=()
    [[ "$ENABLE_OPTIONAL_OFFICE" == "true" ]] && extras+=("Office-suite")
    [[ "$ENABLE_OPTIONAL_HEROIC" == "true" ]] && extras+=("Heroic Games Launcher")
    [[ "$ENABLE_OPTIONAL_VLC" == "true" ]] && extras+=("VLC")

    if [[ ${#extras[@]} -eq 0 ]]; then
        printf "geen"
    else
        local IFS=", "
        printf "%s" "${extras[*]}"
    fi
}

_parse_bootstrap_flags() {
    local arg
    for arg in "$@"; do
        case "$arg" in
            --dry-run)
                DRY_RUN=true
                ;;
            --yes|-y)
                BOOTSTRAP_SKIP_CONFIRM=true
                ;;
            --override)
                BOOTSTRAP_HAS_OVERRIDE_ARG=true
                ;;
        esac
    done
}

_detect_install_mode() {
    if [[ -d "$REPO_DIR/.git" ]]; then
        INSTALL_MODE="update"
    else
        INSTALL_MODE="new"
    fi

    if [[ -e "$HOME/.config/hypr/hyprland.conf" || -e "$HOME/.config/quickshell/Main.qml" ]]; then
        DOTFILES_INSTALLED=true
    else
        DOTFILES_INSTALLED=false
    fi
}

_prompt_yes_no() {
    local question="$1"
    local default="${2:-y}" # y or n

    if "$BOOTSTRAP_SKIP_CONFIRM"; then
        return 0
    fi

    if ! _is_tty; then
        _warn "Niet-interactieve sessie gedetecteerd; ga door met defaults."
        [[ "$default" == "y" ]]
        return $?
    fi

    local suffix="[j/N]"
    [[ "$default" == "y" ]] && suffix="[J/n]"
    printf "  ${CYAN}${BOLD}?${RESET}  %s %s " "$question" "$suffix"

    local answer
    read -r answer
    answer="${answer,,}"

    if [[ -z "$answer" ]]; then
        [[ "$default" == "y" ]]
        return $?
    fi

    [[ "$answer" == "j" || "$answer" == "ja" || "$answer" == "y" || "$answer" == "yes" ]]
}

_prompt_optional_packages() {
    ENABLE_OPTIONAL_OFFICE=false
    ENABLE_OPTIONAL_HEROIC=false
    ENABLE_OPTIONAL_VLC=false

    if ! _prompt_yes_no "Wil je aanvullende pakketten installeren?" "n"; then
        return 0
    fi

    if ! _is_tty; then
        _warn "Geen TTY beschikbaar; aanvullende pakketten worden overgeslagen."
        return 0
    fi

    while true; do
        _clear_screen
        _print_banner
        printf "  ${BOLD}Aanvullende pakketten${RESET}\n"
        printf "  Kies met komma's, bijvoorbeeld ${BOLD}1,3${RESET}. Enter = geen.\n\n"
        printf "    1) Office-suite (ONLYOFFICE)\n"
        printf "    2) Heroic Games Launcher\n"
        printf "    3) VLC mediaspeler\n\n"
        printf "  Keuze: "

        local selection
        read -r selection
        selection="${selection// /}"

        if [[ -z "$selection" ]]; then
            return 0
        fi

        ENABLE_OPTIONAL_OFFICE=false
        ENABLE_OPTIONAL_HEROIC=false
        ENABLE_OPTIONAL_VLC=false

        local valid=true
        local pick
        IFS=',' read -r -a picks <<< "$selection"
        for pick in "${picks[@]}"; do
            case "$pick" in
                1) ENABLE_OPTIONAL_OFFICE=true ;;
                2) ENABLE_OPTIONAL_HEROIC=true ;;
                3) ENABLE_OPTIONAL_VLC=true ;;
                *) valid=false ;;
            esac
        done

        if "$valid"; then
            return 0
        fi

        printf "\n  ${YELLOW}Ongeldige invoer.${RESET} Gebruik alleen 1,2,3 met komma's.\n"
        printf "  Druk Enter om opnieuw te proberen..."
        read -r _
    done
}

_run_bootstrap_wizard() {
    _detect_install_mode

    _clear_screen
    _print_banner
    printf "  ${BOLD}Installatietype:${RESET} %s\n" "$([[ "$INSTALL_MODE" == "new" ]] && echo "Nieuwe installatie" || echo "Bestaande installatie (update)")"
    printf "  ${BOLD}Dotfiles status:${RESET} %s\n" "$([[ "$DOTFILES_INSTALLED" == "true" ]] && echo "al geïnstalleerd" || echo "nog niet geïnstalleerd")"
    printf "  ${BOLD}Repo pad:${RESET}       %s\n\n" "$REPO_DIR"

    if [[ "$INSTALL_MODE" == "new" ]]; then
        _prompt_optional_packages
    fi

    _clear_screen
    _print_banner
    printf "  ${BOLD}Samenvatting${RESET}\n"
    printf "  Type:        %s\n" "$([[ "$INSTALL_MODE" == "new" ]] && echo "Nieuwe installatie" || echo "Update")"
    printf "  Status:      %s\n" "$([[ "$DOTFILES_INSTALLED" == "true" ]] && echo "dotfiles reeds aanwezig" || echo "eerste installatie")"
    printf "  Extra apps:  %s\n" "$(_selected_extras_summary)"
    printf "  Dry-run:     %s\n\n" "$DRY_RUN"

    if ! _prompt_yes_no "Doorgaan met installatie?" "y"; then
        _warn "Geannuleerd voordat repository-updates zijn uitgevoerd."
        exit 0
    fi
}

_detect_repo_ref() {
    if [[ -n "$REPO_REF" ]]; then
        return 0
    fi

    REPO_REF="$(git ls-remote --symref "$REPO_URL" HEAD 2>/dev/null | awk '/^ref:/ {sub("refs/heads/", "", $2); print $2; exit}')"
    [[ -n "$REPO_REF" ]] || REPO_REF="main"
}

_ensure_bootstrap_packages() {
    local -a missing=()

    command -v git  &>/dev/null || missing+=("git")
    command -v curl &>/dev/null || missing+=("curl")

    if [[ ${#missing[@]} -eq 0 ]]; then
        return 0
    fi

    if "$DRY_RUN"; then
        _warn "Ontbrekende bootstrap-pakketten: ${missing[*]}"
        _warn "Dry-run: deze zouden worden geïnstalleerd met pacman."
        return 0
    fi

    command -v sudo &>/dev/null || _die "sudo niet gevonden. Installeer sudo en probeer opnieuw."
    _log "Bootstrap-pakketten installeren: ${missing[*]}"
    sudo pacman -S --needed --noconfirm "${missing[@]}" || _die "Kon bootstrap-pakketten niet installeren: ${missing[*]}"
}

_ensure_aur_helper() {
    if command -v yay &>/dev/null; then
        _ok "AUR-helper gevonden: yay"
        return 0
    fi

    if command -v paru &>/dev/null; then
        _ok "AUR-helper gevonden: paru"
        return 0
    fi

    if "$DRY_RUN"; then
        _warn "Geen AUR-helper gevonden (yay/paru)."
        _warn "Dry-run: yay-bin zou automatisch worden geïnstalleerd."
        return 0
    fi

    _log "Geen AUR-helper gevonden — yay-bin automatisch installeren..."
    command -v sudo &>/dev/null || _die "sudo niet gevonden. Installeer sudo en probeer opnieuw."

    sudo pacman -S --needed --noconfirm base-devel git || _die "Kon vereisten voor yay niet installeren."

    local tmp_dir
    tmp_dir="$(mktemp -d)"

    if ! git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$tmp_dir/yay-bin"; then
        rm -rf "$tmp_dir"
        _die "Kon yay-bin niet klonen vanuit AUR."
    fi

    if ! (cd "$tmp_dir/yay-bin" && makepkg -si --noconfirm); then
        rm -rf "$tmp_dir"
        _die "Automatische installatie van yay-bin mislukt."
    fi

    rm -rf "$tmp_dir"
    command -v yay &>/dev/null || _die "yay is nog steeds niet beschikbaar na installatie."
    _ok "AUR-helper geïnstalleerd: yay"
}

_sync_repo() {
    if [[ -d "$REPO_DIR/.git" ]]; then
        _log "Repo bestaat al — bijwerken: $REPO_DIR"
        git -C "$REPO_DIR" remote set-url origin "$REPO_URL"
        git -C "$REPO_DIR" fetch --quiet origin "$REPO_REF" 2>/dev/null || true
        if git -C "$REPO_DIR" reset --hard "origin/$REPO_REF" && git -C "$REPO_DIR" clean -fd; then
            _ok "Repo bijgewerkt"
        else
            _warn "Bijwerken mislukt; probeer handmatig."
            git -C "$REPO_DIR" reset --hard "origin/$REPO_REF"
        fi
    elif [[ -d "$REPO_DIR" ]]; then
        _warn "Map $REPO_DIR bestaat maar is geen git-repo — herklonen"
        mv "$REPO_DIR" "${REPO_DIR}.bak.$(date +%s)"
        git clone --depth=1 --branch "$REPO_REF" "$REPO_URL" "$REPO_DIR"
        _ok "Repo gekloond (oude map hernoemd naar .bak)"
    else
        _log "Repo klonen naar: $REPO_DIR"
        git clone --depth=1 --branch "$REPO_REF" "$REPO_URL" "$REPO_DIR"
        _ok "Repo gekloond"
    fi
}

_write_bootstrap_override() {
    if "$BOOTSTRAP_HAS_OVERRIDE_ARG"; then
        _warn "Bestaande --override gedetecteerd; bootstrap extras worden genegeerd."
        return 0
    fi

    local needs_override=false
    [[ "$ENABLE_OPTIONAL_OFFICE" == "true" ]] && needs_override=true
    [[ "$ENABLE_OPTIONAL_HEROIC" == "true" ]] && needs_override=true
    [[ "$ENABLE_OPTIONAL_VLC" == "true" ]] && needs_override=true

    if ! "$needs_override"; then
        return 0
    fi

    BOOTSTRAP_OVERRIDE_FILE="$(mktemp "${TMPDIR:-/tmp}/kingstra-bootstrap-overrides.XXXXXX")"
    cat > "$BOOTSTRAP_OVERRIDE_FILE" <<EOF
ENABLE_OPTIONAL_OFFICE=${ENABLE_OPTIONAL_OFFICE}
ENABLE_OPTIONAL_HEROIC=${ENABLE_OPTIONAL_HEROIC}
ENABLE_OPTIONAL_VLC=${ENABLE_OPTIONAL_VLC}
EOF
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
_parse_bootstrap_flags "$@"

_log "Vereisten controleren..."
[[ -f /etc/arch-release ]] || _die "Alleen Arch Linux wordt ondersteund."
command -v bash &>/dev/null || _die "bash niet gevonden."

if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4) )); then
    _die "bash 4.4+ vereist (huidig: $BASH_VERSION)"
fi

_ensure_bootstrap_packages
_run_bootstrap_wizard

_ensure_aur_helper
_detect_repo_ref
_sync_repo
_write_bootstrap_override

_ok "Installer starten..."
printf '\n'

INSTALL_ARGS=("$@")
INSTALL_ARGS+=("--yes")
if [[ -n "$BOOTSTRAP_OVERRIDE_FILE" ]]; then
    INSTALL_ARGS+=("--override" "$BOOTSTRAP_OVERRIDE_FILE")
fi

exec bash "$REPO_DIR/install.sh" "${INSTALL_ARGS[@]}"
