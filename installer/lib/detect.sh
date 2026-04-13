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
#     DETECT_HAS_TOUCHSCREEN — true | false
#     DETECT_HAS_TABLET_MODE_SWITCH — true | false
#     DETECT_HAS_FINGERPRINT — true | false
#
#   Feature-flags (afgeleid — kunnen worden overschreven via --override):
#     ENABLE_VIDEO_WALLPAPER   — true | false
#     ENABLE_POWER_PROFILES    — true | false
#     ENABLE_BRIGHTNESS_CONTROL — true | false
#     TOUCHPAD_NATURAL_SCROLL  — true | false
#     ENABLE_TABLET_MODE       — true | false
#     ENABLE_FINGERPRINT       — true | false
#     ENABLE_SDDM              — true
#     MATUGEN_ENABLED          — true
#     MATUGEN_COLOR_INDEX      — 0
#     ENABLE_SPICETIFY         — false (nooit auto-enabled)
#     ENABLE_VESKTOP           — false (nooit auto-enabled)
#     ENABLE_OPTIONAL_OFFICE   — false (keuze in bootstrap/install wizard)
#     ENABLE_OPTIONAL_HEROIC   — false (keuze in bootstrap/install wizard)
#     ENABLE_OPTIONAL_VLC      — false (keuze in bootstrap/install wizard)
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
    _detect_touchscreen
    _detect_tablet_mode_switch
    _detect_fingerprint

    _derive_feature_flags

    _print_detected_features

    export DETECTED_DISTRO PKG_MANAGER AUR_HELPER WAYLAND_OK
    export DETECT_GPU DETECT_IS_LAPTOP DETECT_HAS_BACKLIGHT DETECT_HAS_TOUCHPAD
    export DETECT_HAS_TOUCHSCREEN DETECT_HAS_TABLET_MODE_SWITCH DETECT_HAS_FINGERPRINT
    export ENABLE_VIDEO_WALLPAPER ENABLE_POWER_PROFILES ENABLE_BRIGHTNESS_CONTROL
    export TOUCHPAD_NATURAL_SCROLL ENABLE_TABLET_MODE ENABLE_FINGERPRINT
    export ENABLE_SDDM MATUGEN_ENABLED MATUGEN_COLOR_INDEX
    export ENABLE_SPICETIFY ENABLE_VESKTOP
    export ENABLE_OPTIONAL_OFFICE ENABLE_OPTIONAL_HEROIC ENABLE_OPTIONAL_VLC
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

_detect_touchscreen() {
    if grep -qiE "touchscreen|touch screen|touch digitizer|digitizer" /proc/bus/input/devices 2>/dev/null; then
        DETECT_HAS_TOUCHSCREEN=true
    elif command -v libinput &>/dev/null && \
         libinput list-devices 2>/dev/null | grep -qiE "touchscreen|touch screen|touch digitizer|digitizer"; then
        DETECT_HAS_TOUCHSCREEN=true
    elif command -v hyprctl &>/dev/null && command -v jq &>/dev/null && \
         hyprctl devices -j 2>/dev/null | jq -e '
             ((.touch? // []) | length) > 0
             or ([.. | objects | .name? // empty | strings
                  | select(test("touch(screen)?|touch digitizer|digitizer"; "i"))] | length) > 0
         ' >/dev/null 2>&1; then
        DETECT_HAS_TOUCHSCREEN=true
    else
        DETECT_HAS_TOUCHSCREEN=false
    fi
}

_detect_tablet_mode_switch() {
    if grep -qiE "tablet mode|tablet.*switch|convertible" /proc/bus/input/devices 2>/dev/null; then
        DETECT_HAS_TABLET_MODE_SWITCH=true
    elif command -v hyprctl &>/dev/null && \
         hyprctl devices 2>/dev/null | grep -qiE "tablet mode|tablet.*switch|convertible"; then
        DETECT_HAS_TABLET_MODE_SWITCH=true
    elif command -v libinput &>/dev/null && \
         libinput list-devices 2>/dev/null | grep -qiE "tablet mode|tablet.*switch|convertible"; then
        DETECT_HAS_TABLET_MODE_SWITCH=true
    else
        DETECT_HAS_TABLET_MODE_SWITCH=false
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

    # Tablet mode: alleen zinvol op convertible hardware of touchscreen-laptops.
    if [[ "$DETECT_HAS_TABLET_MODE_SWITCH" == "true" ]] || \
       [[ "$DETECT_IS_LAPTOP" == "true" && "$DETECT_HAS_TOUCHSCREEN" == "true" ]]; then
        ENABLE_TABLET_MODE=true
    else
        ENABLE_TABLET_MODE=false
    fi

    # Vingerafdruk: alleen als hardware aanwezig is
    ENABLE_FINGERPRINT=$DETECT_HAS_FINGERPRINT

    # Altijd ingeschakeld
    ENABLE_SDDM=true
    MATUGEN_ENABLED=true
    MATUGEN_COLOR_INDEX=0

    # Nooit auto-enabled — gebruiker kiest dit bewust
    ENABLE_SPICETIFY=false
    ENABLE_VESKTOP=false
    ENABLE_OPTIONAL_OFFICE=false
    ENABLE_OPTIONAL_HEROIC=false
    ENABLE_OPTIONAL_VLC=false
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
    export TOUCHPAD_NATURAL_SCROLL ENABLE_TABLET_MODE ENABLE_FINGERPRINT ENABLE_SDDM
    export MATUGEN_ENABLED MATUGEN_COLOR_INDEX ENABLE_SPICETIFY ENABLE_VESKTOP
    export ENABLE_OPTIONAL_OFFICE ENABLE_OPTIONAL_HEROIC ENABLE_OPTIONAL_VLC
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
    log_info " Touchscreen:      $DETECT_HAS_TOUCHSCREEN"
    log_info " Tablet-switch:    $DETECT_HAS_TABLET_MODE_SWITCH"
    log_info " Vingerafdruk:     $DETECT_HAS_FINGERPRINT"
    log_info "─── Feature-flags ─────────────────────────────────"
    log_info " ENABLE_POWER_PROFILES:     $ENABLE_POWER_PROFILES"
    log_info " ENABLE_BRIGHTNESS_CONTROL: $ENABLE_BRIGHTNESS_CONTROL"
    log_info " TOUCHPAD_NATURAL_SCROLL:   $TOUCHPAD_NATURAL_SCROLL"
    log_info " ENABLE_TABLET_MODE:        $ENABLE_TABLET_MODE"
    log_info " ENABLE_FINGERPRINT:        $ENABLE_FINGERPRINT"
    log_info " ENABLE_VIDEO_WALLPAPER:    $ENABLE_VIDEO_WALLPAPER"
    log_info " ENABLE_OPTIONAL_OFFICE:    $ENABLE_OPTIONAL_OFFICE"
    log_info " ENABLE_OPTIONAL_HEROIC:    $ENABLE_OPTIONAL_HEROIC"
    log_info " ENABLE_OPTIONAL_VLC:       $ENABLE_OPTIONAL_VLC"
    log_info "────────────────────────────────────────────────────"
}
