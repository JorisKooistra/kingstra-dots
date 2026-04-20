#!/usr/bin/env bash
# =============================================================================
# packages.sh — Pakketinstallatie (pacman + AUR)
# =============================================================================

# Installeer een lijst van pacman-pakketten
pacman_install() {
    local -a pkgs=("$@")
    [[ ${#pkgs[@]} -eq 0 ]] && return 0

    local -a to_install=()
    for pkg in "${pkgs[@]}"; do
        # Lege regels en commentaarregels overslaan
        [[ -z "$pkg" || "$pkg" == \#* ]] && continue
        if ! pacman -Qi "$pkg" &>/dev/null; then
            to_install+=("$pkg")
        else
            log_info "Al geïnstalleerd: $pkg"
        fi
    done

    [[ ${#to_install[@]} -eq 0 ]] && return 0

    log_step "pacman installeren: ${to_install[*]}"
    if ! INSTALL_NEXT_RUN_LABEL="pacman installeren: ${to_install[*]}" \
        run_cmd sudo pacman -S --needed --noconfirm "${to_install[@]}"; then
        _package_install_hint "pacman"
        return 1
    fi
}

_package_refresh_sudo() {
    "${DRY_RUN:-false}" && return 0
    [[ "${EUID:-$(id -u)}" -eq 0 ]] && return 0
    sudo -n true >/dev/null 2>&1 && return 0

    if [[ -t 0 ]]; then
        log_step "sudo-sessie verversen voor pakketinstallatie..."
        sudo -v
        return $?
    fi

    return 0
}

# Installeer een lijst van AUR-pakketten
aur_install() {
    local -a pkgs=("$@")
    [[ ${#pkgs[@]} -eq 0 ]] && return 0

    if [[ -z "${AUR_HELPER:-}" ]]; then
        log_warn "Geen AUR-helper beschikbaar. AUR-pakketten worden overgeslagen: ${pkgs[*]}"
        return 0
    fi

    local -a to_install=()
    for pkg in "${pkgs[@]}"; do
        [[ -z "$pkg" || "$pkg" == \#* ]] && continue
        if ! "$AUR_HELPER" -Qi "$pkg" &>/dev/null 2>&1; then
            to_install+=("$pkg")
        else
            log_info "Al geïnstalleerd (AUR): $pkg"
        fi
    done

    [[ ${#to_install[@]} -eq 0 ]] && return 0

    log_step "$AUR_HELPER installeren: ${to_install[*]}"

    # Voorkom dat de AUR-helper een pager opent (less/bat/diff-so-fancy), op
    # verborgen prompts wacht, of de terminal manipuleert. PAGER=cat garandeert
    # geen interactieve pager ongeacht user-config.
    local -a aur_flags=(--needed --noconfirm)
    case "${AUR_HELPER##*/}" in
        paru) aur_flags+=(--skipreview) ;;
        yay)
            aur_flags+=(
                --aur
                --answerdiff=None
                --answerclean=None
                --answeredit=None
                --answerupgrade=None
                --batchinstall
                --noredownload
                --norebuild
                --noremovemake
                --noprogressbar
                --sudoloop
            )
            ;;
    esac

    if ! _package_refresh_sudo; then
        _package_install_hint "sudo"
        return 1
    fi

    if ! PAGER=cat INSTALL_NEXT_RUN_LABEL="$AUR_HELPER installeren: ${to_install[*]}" \
        run_cmd "$AUR_HELPER" -S "${aur_flags[@]}" "${to_install[@]}"; then
        _package_install_hint "$AUR_HELPER"
        return 1
    fi

    # Herstel terminal-staat voor het geval de AUR-helper toch iets heeft
    # aangepast (alternate screen, mouse reporting, line discipline).
    if [[ -t 1 && "${TERM:-}" != "dumb" ]]; then
        stty sane 2>/dev/null || true
        printf '\033[?1049l\033[?1000l\033[?1002l\033[?1003l\033[?1006l' 2>/dev/null || true
    fi
}

_package_install_hint() {
    local tool="$1"

    log_warn "$tool kon pakketten niet installeren."
    log_warn "Als de uitvoer 'could not resolve host' of 'Could not resolve host' noemt, is dit DNS/netwerk/mirror-resolutie en niet het pakket zelf."
    log_warn "Controleer eerst netwerk en DNS:"
    log_warn "  nmcli general status"
    log_warn "  resolvectl status"
    log_warn "  getent hosts archlinux.org"
    log_warn "Daarna pacman database/mirrors verversen:"
    log_warn "  sudo pacman -Syyu"
    log_warn "Blijft het fout gaan, ververs mirrors met reflector of kies tijdelijk andere mirrors."
}

# Installeer pakketten vanuit een manifestbestand
# Lijnen die beginnen met '#' worden genegeerd.
# Lijnen die beginnen met 'aur:' worden via AUR geïnstalleerd.
install_from_manifest() {
    local manifest_file="$1"

    if [[ ! -f "$manifest_file" ]]; then
        log_warn "Manifest niet gevonden: $manifest_file"
        return 0
    fi

    log_step "Pakketten installeren vanuit: $manifest_file"

    local -a pac_pkgs=()
    local -a aur_pkgs=()

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Commentaar en lege regels overslaan
        [[ -z "$line" || "$line" == \#* ]] && continue

        if [[ "$line" == aur:* ]]; then
            aur_pkgs+=("${line#aur:}")
        else
            pac_pkgs+=("$line")
        fi
    done < "$manifest_file"

    pacman_install "${pac_pkgs[@]+"${pac_pkgs[@]}"}"
    aur_install "${aur_pkgs[@]+"${aur_pkgs[@]}"}"
}
