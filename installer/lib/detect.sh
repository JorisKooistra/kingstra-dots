#!/usr/bin/env bash
# =============================================================================
# detect.sh — Hardwaredetectie per variabele
# =============================================================================
# Elke feature wordt onafhankelijk gedetecteerd op basis van aanwezig hardware.
# Geen profielen nodig — een laptop met Nvidia krijgt automatisch beide sets.
#
# Geëxporteerde variabelen na detect_system():
#
#   Systeem:
#     DETECTED_DISTRO      — "arch" | "unknown"
#     PKG_MANAGER          — "pacman"
#     AUR_HELPER           — "yay" | "paru" | ""
#     WAYLAND_OK           — true | false
#
#   Hardware (feiten):
#     DETECT_GPU           — "nvidia" | "amd" | "intel" | "unknown"
#     DETECT_IS_LAPTOP     — true | false  (batterij aanwezig)
#     DETECT_HAS_BACKLIGHT — true | false  (/sys/class/backlight)
#     DETECT_HAS_TOUCHPAD  — true | false
#     DETECT_HAS_FINGERPRINT — true | false
#
#   Feature-flags (afgeleid — kunnen worden overschreven via --override):
#     ENABLE_VIDEO_WALLPAPER   — true | false
#     ENABLE_POWER_PROFILES    — true | false
#     ENABLE_BRIGHTNESS_CONTROL — true | false
#     TOUCHPAD_NATURAL_SCROLL  — true | false
#     ENABLE_FINGERPRINT       — true | false
#     ENABLE_SDDM              — true
#     MATUGEN_ENABLED          — true
#     MATUGEN_COLOR_INDEX      — 0
#     ENABLE_SPICETIFY         — false (nooit auto-enabled)
#     ENABLE_VESKTOP           — false (nooit auto-enabled)
# =============================================================================

detect_system() {
    log_step "Systeem en hardware detecteren..."

    _detect_distro
    _detect_aur_helper
    _detect_wayland

    _detect_gpu
    _detect_laptop
    _detect_backlight
    _detect_touchpad
    _detect_fingerprint

    _derive_feature_flags

    _print_detected_features

    export DETECTED_DISTRO PKG_MANAGER AUR_HELPER WAYLAND_OK
    export DETECT_GPU DETECT_IS_LAPTOP DETECT_HAS_BACKLIGHT DETECT_HAS_TOUCHPAD DETECT_HAS_FINGERPRINT
    export ENABLE_VIDEO_WALLPAPER ENABLE_POWER_PROFILES ENABLE_BRIGHTNESS_CONTROL
    export TOUCHPAD_NATURAL_SCROLL ENABLE_FINGERPRINT
    export ENABLE_SDDM MATUGEN_ENABLED MATUGEN_COLOR_INDEX
    export ENABLE_SPICETIFY ENABLE_VESKTOP
}

# ---------------------------------------------------------------------------
# Systeem
# ---------------------------------------------------------------------------
_detect_distro() {
    if [[ -f /etc/arch-release ]]; then
        DETECTED_DISTRO="arch"
        PKG_MANAGER="pacman"
    else
        DETECTED_DISTRO="unknown"
        PKG_MANAGER="unknown"
        log_warn "Geen Arch Linux gedetecteerd. Deze installer is ontworpen voor Arch."
    fi
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
}

_detect_wayland() {
    if [[ "${WAYLAND_DISPLAY:-}" != "" ]] || [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]]; then
        WAYLAND_OK=true
    else
        WAYLAND_OK=false
    fi
}

# ---------------------------------------------------------------------------
# Hardware — feiten
# ---------------------------------------------------------------------------
_detect_gpu() {
    local pci_out
    pci_out="$(lspci 2>/dev/null || true)"
    if echo "$pci_out" | grep -qi "nvidia"; then
        DETECT_GPU="nvidia"
    elif echo "$pci_out" | grep -qi "amd\|radeon\|advanced micro devices"; then
        DETECT_GPU="amd"
    elif echo "$pci_out" | grep -qi "intel.*graphics\|intel.*uhd\|intel.*iris"; then
        DETECT_GPU="intel"
    else
        DETECT_GPU="unknown"
    fi
}

_detect_laptop() {
    if compgen -G "/sys/class/power_supply/BAT*" > /dev/null 2>&1; then
        DETECT_IS_LAPTOP=true
    else
        DETECT_IS_LAPTOP=false
    fi
}

_detect_backlight() {
    local bl_dir="/sys/class/backlight"
    if [[ -d "$bl_dir" ]] && [[ -n "$(ls -A "$bl_dir" 2>/dev/null)" ]]; then
        DETECT_HAS_BACKLIGHT=true
    else
        DETECT_HAS_BACKLIGHT=false
    fi
}

_detect_touchpad() {
    # Controleer /proc/bus/input/devices op "TouchPad" of "Synaptics"
    if grep -qiE "touchpad|synaptics|trackpad" /proc/bus/input/devices 2>/dev/null; then
        DETECT_HAS_TOUCHPAD=true
    # Fallback: libinput list-devices (als beschikbaar)
    elif command -v libinput &>/dev/null && \
         libinput list-devices 2>/dev/null | grep -qi "touchpad"; then
        DETECT_HAS_TOUCHPAD=true
    else
        DETECT_HAS_TOUCHPAD=false
    fi
}

_detect_fingerprint() {
    # Controleer op bekende fingerprint USB-vendorIDs of fprintd-apparaat
    if lsusb 2>/dev/null | grep -qiE "fingerprint|27c6|06cb|138a|0483:2016|1c7a"; then
        DETECT_HAS_FINGERPRINT=true
    elif [[ -e /dev/fingerprint0 ]] || \
         command -v fprintd-list &>/dev/null && fprintd-list "$USER" &>/dev/null 2>&1; then
        DETECT_HAS_FINGERPRINT=true
    else
        DETECT_HAS_FINGERPRINT=false
    fi
}

# ---------------------------------------------------------------------------
# Feature-flags afleiden uit hardware-feiten
# ---------------------------------------------------------------------------
_derive_feature_flags() {
    # Videowallpaper: altijd beschikbaar als mpvpaper geïnstalleerd is (fase 9 beheert dit)
    ENABLE_VIDEO_WALLPAPER=true

    # Power profiles: zinvol op laptops
    if $DETECT_IS_LAPTOP; then
        ENABLE_POWER_PROFILES=true
    else
        ENABLE_POWER_PROFILES=false
    fi

    # Helderheidsregeling: alleen als backlight aanwezig is
    ENABLE_BRIGHTNESS_CONTROL=$DETECT_HAS_BACKLIGHT

    # Touchpad: natural scroll als touchpad aanwezig is
    TOUCHPAD_NATURAL_SCROLL=$DETECT_HAS_TOUCHPAD

    # Vingerafdruk: alleen als hardware aanwezig is
    ENABLE_FINGERPRINT=$DETECT_HAS_FINGERPRINT

    # Altijd ingeschakeld
    ENABLE_SDDM=true
    MATUGEN_ENABLED=true
    MATUGEN_COLOR_INDEX=0

    # Nooit auto-enabled — gebruiker kiest dit bewust
    ENABLE_SPICETIFY=false
    ENABLE_VESKTOP=false
}

# ---------------------------------------------------------------------------
# Overschrijf gedetecteerde waarden vanuit een optioneel override-bestand
# ---------------------------------------------------------------------------
# Gebruik: apply_overrides "pad/naar/overrides.conf"
# Het bestand kan variabelassignments bevatten zoals:
#   ENABLE_FINGERPRINT=false
#   ENABLE_VIDEO_WALLPAPER=false
apply_overrides() {
    local override_file="${1:-}"
    [[ -z "$override_file" || ! -f "$override_file" ]] && return 0

    log_info "Override-bestand toepassen: $override_file"
    # shellcheck source=/dev/null
    source "$override_file"

    # Herexporteer zodat fases de nieuwe waarden zien
    export ENABLE_VIDEO_WALLPAPER ENABLE_POWER_PROFILES ENABLE_BRIGHTNESS_CONTROL
    export TOUCHPAD_NATURAL_SCROLL ENABLE_FINGERPRINT ENABLE_SDDM
    export MATUGEN_ENABLED MATUGEN_COLOR_INDEX ENABLE_SPICETIFY ENABLE_VESKTOP
}

# ---------------------------------------------------------------------------
# Gedetecteerde waarden afdrukken
# ---------------------------------------------------------------------------
_print_detected_features() {
    log_info "─── Detectieresultaten ────────────────────────────"
    log_info " GPU:              $DETECT_GPU"
    log_info " Laptop/batterij:  $DETECT_IS_LAPTOP"
    log_info " Backlight:        $DETECT_HAS_BACKLIGHT"
    log_info " Touchpad:         $DETECT_HAS_TOUCHPAD"
    log_info " Vingerafdruk:     $DETECT_HAS_FINGERPRINT"
    log_info "─── Feature-flags ─────────────────────────────────"
    log_info " ENABLE_POWER_PROFILES:     $ENABLE_POWER_PROFILES"
    log_info " ENABLE_BRIGHTNESS_CONTROL: $ENABLE_BRIGHTNESS_CONTROL"
    log_info " TOUCHPAD_NATURAL_SCROLL:   $TOUCHPAD_NATURAL_SCROLL"
    log_info " ENABLE_FINGERPRINT:        $ENABLE_FINGERPRINT"
    log_info " ENABLE_VIDEO_WALLPAPER:    $ENABLE_VIDEO_WALLPAPER"
    log_info "────────────────────────────────────────────────────"
}
