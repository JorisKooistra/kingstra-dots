#!/usr/bin/env bash
# Wifi-hotspot via NetworkManager, voor de knop in Snelle instellingen.
#   hotspot.sh status   JSON: {"available","active","ssid","password","qr"}
#   hotspot.sh on|off|toggle
# De verbinding heet "Kingstra-hotspot" en onthoudt naam en wachtwoord, zodat
# een telefoon hem de volgende keer vanzelf weer vindt. De QR-code (qrencode)
# komt in $XDG_RUNTIME_DIR/kingstra-hotspot-qr.png.
set -uo pipefail

CON="Kingstra-hotspot"
RUN="${XDG_RUNTIME_DIR:-/tmp}"
QR="$RUN/kingstra-hotspot-qr.png"

wifi_dev() {
    nmcli -t -f DEVICE,TYPE device 2>/dev/null | awk -F: '$2=="wifi"{print $1; exit}'
}

json_str() {
    python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"
}

is_active() {
    nmcli -t -f NAME connection show --active 2>/dev/null | grep -qxF "$CON"
}

status() {
    local dev active=false ssid="" pass="" qr=""
    dev=$(wifi_dev)
    if [[ -z "$dev" ]]; then
        printf '{"available":false,"active":false,"ssid":"","password":"","qr":""}\n'
        return
    fi
    if is_active; then
        active=true
        ssid=$(nmcli -g 802-11-wireless.ssid connection show "$CON" 2>/dev/null)
        pass=$(nmcli -s -g 802-11-wireless-security.psk connection show "$CON" 2>/dev/null)
        if command -v qrencode >/dev/null 2>&1 && [[ -n "$ssid" ]]; then
            # Speciale tekens in het WIFI:-formaat moeten een backslash krijgen.
            local es ep
            es=$(printf '%s' "$ssid" | sed 's/[\;,:"]/\\&/g')
            ep=$(printf '%s' "$pass" | sed 's/[\;,:"]/\\&/g')
            qrencode -s 8 -m 2 -o "$QR" "WIFI:T:WPA;S:${es};P:${ep};;" 2>/dev/null && qr="$QR"
        fi
    fi
    printf '{"available":true,"active":%s,"ssid":%s,"password":%s,"qr":%s}\n' \
        "$active" "$(json_str "$ssid")" "$(json_str "$pass")" "$(json_str "$qr")"
}

on() {
    local dev
    dev=$(wifi_dev)
    [[ -n "$dev" ]] || { echo "Geen wifi-kaart gevonden" >&2; exit 1; }
    nmcli radio wifi on >/dev/null 2>&1
    if nmcli -t -f NAME connection show 2>/dev/null | grep -qxF "$CON"; then
        nmcli connection up "$CON" ifname "$dev" >/dev/null
    else
        local ssid pass
        ssid="$(hostname 2>/dev/null || echo kingstra)-hotspot"
        pass=$(tr -dc 'a-hjkmnp-z2-9' < /dev/urandom 2>/dev/null | head -c 12)
        nmcli device wifi hotspot ifname "$dev" con-name "$CON" ssid "$ssid" password "$pass" >/dev/null
    fi
}

off() {
    nmcli connection down "$CON" >/dev/null 2>&1
    rm -f "$QR"
}

case "${1:-status}" in
    status) status ;;
    on) on ;;
    off) off ;;
    toggle) if is_active; then off; else on; fi ;;
    *) echo "gebruik: hotspot.sh status|on|off|toggle" >&2; exit 2 ;;
esac
