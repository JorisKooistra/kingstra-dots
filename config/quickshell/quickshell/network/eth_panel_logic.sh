#!/usr/bin/env bash

# Use LC_ALL=C to prevent nmcli from translating "connected" to other languages
# Redirect stderr to /dev/null to cleanly handle scenarios where NetworkManager isn't running
ETH_DEV=$(LC_ALL=C nmcli -t -f DEVICE,TYPE,STATE d 2>/dev/null | awk -F: '$2=="ethernet" && $3=="connected" {print $1; exit}')

# If no device is connected, return offline state
if [[ -z "$ETH_DEV" ]]; then
    jq -nc --arg power "off" '{ "power": $power, "connected": null }'
    exit 0
fi

# Fetch connection statistics
IP=$(ip -4 addr show dev "$ETH_DEV" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
[ -z "$IP" ] && IP="No IP"

SPEED=$(cat /sys/class/net/"$ETH_DEV"/speed 2>/dev/null)
[ -n "$SPEED" ] && SPEED="${SPEED} Mbps" || SPEED="Unknown"

MAC=$(cat /sys/class/net/"$ETH_DEV"/address 2>/dev/null)

# Apply LC_ALL=C here as well to ensure consistent parsing
PROFILE=$(LC_ALL=C nmcli -t -f NAME,DEVICE c show --active 2>/dev/null | grep "$ETH_DEV" | cut -d: -f1 | head -n1)
[ -z "$PROFILE" ] && PROFILE="Wired Connection"

# Use jq -nc (-c for compact) to output a clean, single-line JSON string natively
CONNECTED_JSON=$(jq -nc \
    --arg id "$ETH_DEV" \
    --arg name "$PROFILE" \
    --arg icon "󰈀" \
    --arg ip "$IP" \
    --arg speed "$SPEED" \
    --arg mac "$MAC" \
    '{id: $id, name: $name, icon: $icon, ip: $ip, speed: $speed, mac: $mac}')

jq -nc \
    --arg power "on" \
    --argjson connected "$CONNECTED_JSON" \
    '{power: $power, connected: $connected}'
