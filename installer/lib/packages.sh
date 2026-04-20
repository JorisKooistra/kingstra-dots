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
    run_cmd sudo pacman -S --needed --noconfirm "${to_install[@]}"
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

    # Voorkom dat de AUR-helper een pager opent (less/bat/diff-so-fancy) of de
    # terminal manipuleert (alternate screen buffer, mouse tracking).
    # --skipreview (paru) / --answerdiff=None etc. (yay) slaan PKGBUILD-reviews
    # over. PAGER=cat garandeert geen interactieve pager ongeacht config.
    local -a aur_flags=(--needed --noconfirm)
    case "${AUR_HELPER##*/}" in
        paru) aur_flags+=(--skipreview) ;;
        yay)  aur_flags+=(--answerdiff=None --answerclean=None --answeredit=None) ;;
    esac

    PAGER=cat run_cmd "$AUR_HELPER" -S "${aur_flags[@]}" "${to_install[@]}"

    # Herstel terminal-staat voor het geval de AUR-helper toch iets heeft
    # aangepast (alternate screen, mouse reporting, line discipline).
    if [[ -t 1 && "${TERM:-}" != "dumb" ]]; then
        stty sane 2>/dev/null || true
        printf '\033[?1049l\033[?1000l\033[?1002l\033[?1003l\033[?1006l' 2>/dev/null || true
    fi
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
