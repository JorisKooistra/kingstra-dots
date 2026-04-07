#!/usr/bin/env bash
# =============================================================================
# detect.sh — Systeemdetectie
# =============================================================================

# Geëxporteerde variabelen na detect_system():
#   DETECTED_DISTRO   — "arch" | "unknown"
#   PKG_MANAGER       — "pacman"
#   AUR_HELPER        — "yay" | "paru" | ""
#   HAS_NVIDIA        — "ja" | "nee"
#   IS_LAPTOP         — "ja" | "nee"
#   HAS_FINGERPRINT   — "ja" | "nee"
#   WAYLAND_OK        — "ja" | "nee"

detect_system() {
    log_step "Systeem detecteren..."

    _detect_distro
    _detect_aur_helper
    _detect_nvidia
    _detect_laptop
    _detect_fingerprint
    _detect_wayland
    _detect_profile_auto

    export DETECTED_DISTRO PKG_MANAGER AUR_HELPER HAS_NVIDIA IS_LAPTOP HAS_FINGERPRINT WAYLAND_OK PROFILE_AUTO
}

_detect_distro() {
    if [[ -f /etc/arch-release ]]; then
        DETECTED_DISTRO="arch"
        PKG_MANAGER="pacman"
    else
        DETECTED_DISTRO="unknown"
        PKG_MANAGER="unknown"
        log_warn "Geen Arch Linux gedetecteerd. Deze installer is ontworpen voor Arch."
    fi
    log_info "Distro: $DETECTED_DISTRO"
}

_detect_aur_helper() {
    if command -v yay &>/dev/null; then
        AUR_HELPER="yay"
    elif command -v paru &>/dev/null; then
        AUR_HELPER="paru"
    else
        AUR_HELPER=""
        log_warn "Geen AUR-helper gevonden (yay/paru). AUR-pakketten kunnen niet automatisch worden geïnstalleerd."
    fi
    log_info "AUR-helper: ${AUR_HELPER:-geen}"
}

_detect_nvidia() {
    if lspci 2>/dev/null | grep -qi "nvidia"; then
        HAS_NVIDIA="ja"
    else
        HAS_NVIDIA="nee"
    fi
    log_info "Nvidia GPU: $HAS_NVIDIA"
}

_detect_laptop() {
    # Laptops hebben een batterij
    if ls /sys/class/power_supply/BAT* &>/dev/null; then
        IS_LAPTOP="ja"
    else
        IS_LAPTOP="nee"
    fi
    log_info "Laptop: $IS_LAPTOP"
}

_detect_fingerprint() {
    if lsusb 2>/dev/null | grep -qi "fingerprint" || ls /dev/input/fingerprint* &>/dev/null 2>&1; then
        HAS_FINGERPRINT="ja"
    else
        HAS_FINGERPRINT="nee"
    fi
    log_info "Vingerafdrukscanner: $HAS_FINGERPRINT"
}

_detect_wayland() {
    if [[ -n "${WAYLAND_DISPLAY:-}" ]] || [[ -n "${XDG_SESSION_TYPE:-}" && "$XDG_SESSION_TYPE" == "wayland" ]]; then
        WAYLAND_OK="ja"
    else
        WAYLAND_OK="nee"
        log_warn "Geen actieve Wayland-sessie gedetecteerd."
    fi
    log_info "Wayland actief: $WAYLAND_OK"
}

# Bepaal automatisch het beste profiel op basis van detectie.
# Prioriteit: laptop+nvidia > laptop > nvidia > default
# Kan altijd worden overschreven met --profile.
_detect_profile_auto() {
    if [[ "$IS_LAPTOP" == "ja" && "$HAS_NVIDIA" == "ja" ]]; then
        PROFILE_AUTO="laptop"   # laptop.conf sourcet default; nvidia-envvars worden apart in hypr gezet
        log_info "Auto-profiel: laptop (Nvidia GPU + batterij gedetecteerd)"
    elif [[ "$IS_LAPTOP" == "ja" ]]; then
        PROFILE_AUTO="laptop"
        log_info "Auto-profiel: laptop (batterij gedetecteerd)"
    elif [[ "$HAS_NVIDIA" == "ja" ]]; then
        PROFILE_AUTO="nvidia"
        log_info "Auto-profiel: nvidia (Nvidia GPU gedetecteerd)"
    else
        PROFILE_AUTO="default"
        log_info "Auto-profiel: default"
    fi
}
