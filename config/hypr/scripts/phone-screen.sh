#!/usr/bin/env bash
# =============================================================================
# phone-screen.sh — schermen tussen pc en Android-telefoon (paneel Telefoon).
#
#   phone-screen.sh tools          JSON met wat er is en wat er loopt
#   phone-screen.sh mirror [stop|toggle]
#                                  telefoonscherm op de pc (scrcpy), via wifi
#   phone-screen.sh share on|off|toggle|status
#                                  pc-scherm naar de telefoon (wayvnc)
#
# Telefoon → pc: scrcpy via adb. De eerste keer met een kabel (USB-
# foutopsporing aan); daarna zet dit script adb op wifi en onthoudt het
# IP-adres, zodat het voortaan zonder kabel werkt. Zuinig: het scherm van de
# telefoon gaat uit zolang hij op de pc staat, en bij sluiten gaat het meteen
# weer aan. Na een herstart van de telefoon is één keer de kabel weer nodig
# (Android zet adb-wifi dan uit).
#
# Pc → telefoon: wayvnc deelt het scherm met de muis erop. Het luistert
# alleen op het Tailscale-adres van deze pc, dus alleen je eigen apparaten
# in je tailnet kunnen erbij (thuis én onderweg). Op de telefoon: de
# Tailscale-app plus een VNC-app (bijv. AVNC), adres <tailscale-ip>:5900.
# Het delen blijft aan tot je het in het paneel weer uitzet.
# =============================================================================
set -uo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/kingstra"
IP_FILE="$STATE_DIR/phone-adb-ip"
VNC_PORT=5900
VNC_SOCK="${XDG_RUNTIME_DIR:-/tmp}/kingstra-wayvnc.sock"
FEEDBACK="$HOME/.config/hypr/scripts/feedback.sh"

say() { bash "$FEEDBACK" "$1" "$2" "${3:-}" "${4:-6000}" >/dev/null 2>&1 || true; }
has() { command -v "$1" >/dev/null 2>&1; }

vnc_running() { pgrep -u "$UID" -x wayvnc >/dev/null 2>&1; }
tailscale_ip() { ip -4 -o addr show tailscale0 2>/dev/null | awk '{split($4, a, "/"); print a[1]; exit}'; }

mirror_running() { pgrep -u "$UID" -x scrcpy >/dev/null 2>&1; }

tools() {
    printf '{"scrcpy":%s,"wayvnc":%s,"vnc":%s,"mirror":%s,"wifiKnown":%s,"tailscale":"%s","port":%s}\n' \
        "$(has scrcpy && echo true || echo false)" \
        "$(has wayvnc && echo true || echo false)" \
        "$(vnc_running && echo true || echo false)" \
        "$(mirror_running && echo true || echo false)" \
        "$([[ -s "$IP_FILE" ]] && echo true || echo false)" \
        "$(tailscale_ip)" "$VNC_PORT"
}

# --- Telefoon → pc ------------------------------------------------------------
usb_serial() {
    # Eerste apparaat dat via usb hangt (serienummer zonder ":poort").
    adb devices 2>/dev/null | awk 'NR > 1 && $2 == "device" && $1 !~ /:/ {print $1; exit}'
}

phone_wifi_ip() {
    adb -s "$1" shell ip -4 -o addr show wlan0 2>/dev/null \
        | awk '{split($4, a, "/"); print a[1]; exit}' | tr -d '\r'
}

# Scherm van de telefoon uit tijdens spiegelen; bij sluiten zet scrcpy het
# zelf weer aan, en phone_wake() zorgt dat het echt aan staat.
SCRCPY_OPTS=(--turn-screen-off --max-fps=60)

# Telefoonscherm aan na het spiegelen (ook als scrcpy is afgebroken).
phone_wake() {
    local dev="$1"
    [[ -n "$dev" ]] || return 0
    timeout 5 adb -s "$dev" shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1 || true
}

# scrcpy draaien en daarna het telefoonscherm weer aanzetten.
run_scrcpy() {
    local dev="$1"; shift
    local rc=0
    scrcpy --window-title=Telefoon "${SCRCPY_OPTS[@]}" "$@" || rc=$?
    phone_wake "$dev"
    return "$rc"
}

mirror_stop() { mirror_running && pkill -u "$UID" -x scrcpy; return 0; }

mirror() {
    if mirror_running; then
        hyprctl dispatch focuswindow "title:^Telefoon$" >/dev/null 2>&1
        return 0
    fi
    if ! has scrcpy || ! has adb; then
        say "󰍹" "scrcpy ontbreekt" "Draai kingstra update of: sudo pacman -S scrcpy android-tools"
        return 1
    fi
    mkdir -p "$STATE_DIR"
    local serial ip
    serial="$(usb_serial)"
    if [[ -n "$serial" ]]; then
        # Kabel zit erin: IP onthouden en adb meteen op wifi zetten.
        ip="$(phone_wifi_ip "$serial")"
        if [[ -n "$ip" ]]; then
            printf '%s\n' "$ip" > "$IP_FILE"
            say "󰍹" "Telefoon gevonden" "Volgende keer werkt het ook zonder kabel." 4000
            run_scrcpy "$ip:5555" --tcpip --serial="$serial"
            local rc=$?
            # Kabel zit er misschien nog in: dan ook via usb wekken.
            phone_wake "$serial"
            return "$rc"
        fi
        run_scrcpy "$serial" --serial="$serial"
        return $?
    fi
    ip="$(cat "$IP_FILE" 2>/dev/null)"
    if [[ -n "$ip" ]]; then
        if run_scrcpy "$ip:5555" --tcpip="$ip:5555"; then
            return 0
        fi
        say "󰍹" "Telefoon niet bereikt via wifi" \
            "Zit hij op hetzelfde netwerk? Na een herstart van de telefoon: één keer met de kabel aansluiten." 7000
        return 1
    fi
    say "󰍹" "Eerst één keer met een kabel" \
        "Zet USB-foutopsporing aan (Instellingen › Ontwikkelaarsopties), sluit de telefoon aan en sta de pc toe. Daarna werkt het via wifi." 9000
    return 1
}

# --- Pc → telefoon ------------------------------------------------------------
focused_output() {
    hyprctl -j monitors 2>/dev/null | python3 -I -c \
        'import json,sys; m=[x for x in json.load(sys.stdin) if x.get("focused")]; print(m[0]["name"] if m else "")' 2>/dev/null
}

share_on() {
    if ! has wayvnc; then
        say "󰍺" "wayvnc ontbreekt" "Draai kingstra update of: sudo pacman -S wayvnc"
        return 1
    fi
    if vnc_running; then
        share_status_msg
        return 0
    fi
    local ip out
    ip="$(tailscale_ip)"
    if [[ -z "$ip" ]]; then
        say "󰍺" "Tailscale staat uit" "Het scherm wordt alleen via Tailscale gedeeld. Zet Tailscale aan en probeer opnieuw." 7000
        return 1
    fi
    out="$(focused_output)"
    local args=(--max-fps=30 --socket="$VNC_SOCK")
    [[ -n "$out" ]] && args+=(--output="$out")
    setsid -f wayvnc "${args[@]}" "$ip" "$VNC_PORT" >/dev/null 2>&1 < /dev/null
    sleep 0.6
    if ! vnc_running; then
        say "󰍺" "Scherm delen lukte niet" "wayvnc startte niet. Zie: wayvnc --help" 6000
        return 1
    fi
    say "󰍺" "Pc-scherm gedeeld${out:+ ($out)}" "Op je telefoon in de VNC-app: $ip:$VNC_PORT. Zet het in het paneel weer uit." 9000
}

share_off() {
    vnc_running || return 0
    if has wayvncctl; then
        wayvncctl --socket="$VNC_SOCK" wayvnc-exit >/dev/null 2>&1
        sleep 0.3
    fi
    vnc_running && pkill -u "$UID" -x wayvnc
    say "󰍺" "Scherm delen gestopt" "" 2500
}

share_status_msg() {
    local ip; ip="$(tailscale_ip)"
    say "󰍺" "Pc-scherm wordt gedeeld" "VNC-adres: ${ip:-?}:$VNC_PORT" 6000
}

case "${1:-}" in
    tools) tools ;;
    mirror)
        case "${2:-start}" in
            start) mirror ;;
            stop) mirror_stop ;;
            toggle) if mirror_running; then mirror_stop; else mirror; fi ;;
            *) echo "gebruik: phone-screen.sh mirror [start|stop|toggle]" >&2; exit 2 ;;
        esac ;;
    share)
        case "${2:-toggle}" in
            on) share_on ;;
            off) share_off ;;
            toggle) if vnc_running; then share_off; else share_on; fi ;;
            status) vnc_running && echo on || echo off ;;
            *) echo "gebruik: phone-screen.sh share on|off|toggle|status" >&2; exit 2 ;;
        esac ;;
    *) echo "gebruik: phone-screen.sh tools|mirror|share on|off|toggle|status" >&2; exit 2 ;;
esac
