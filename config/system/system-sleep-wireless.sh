#!/usr/bin/env bash
# =============================================================================
# kingstra-wireless — systemd system-sleep hook voor WiFi/Bluetooth-herstel
# =============================================================================
# Geïnstalleerd door kingstra-dots (fase 12) naar
# /usr/lib/systemd/system-sleep/kingstra-wireless. Draait als root direct na
# resume, vóór de kingstra-resume user service.
#
# Herstelt de twee klassieke resume-problemen:
#   1. Bluetooth-adapter verdwenen (btusb hangt) → module herladen
#   2. Radio's soft-blocked na resume → rfkill unblock
# =============================================================================

case "${1:-}" in
    post)
        # Bluetooth-adapter kwijt? Herlaad btusb.
        if ! ls /sys/class/bluetooth/ 2>/dev/null | grep -q hci; then
            modprobe -r btusb 2>/dev/null || true
            sleep 1
            modprobe btusb 2>/dev/null || true
        fi

        command -v rfkill >/dev/null 2>&1 && rfkill unblock wifi bluetooth 2>/dev/null || true
        ;;
esac

exit 0
