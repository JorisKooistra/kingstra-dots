#!/usr/bin/env bash

cmd="$1"

# Handle Power Toggle (Mapped to Mute for Audio)
if [[ "$cmd" == "--toggle-mute" ]]; then
    if command -v wpctl >/dev/null; then
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    else
        pactl set-sink-mute @DEFAULT_SINK@ toggle
    fi
    exit 0
fi

# Fetch default sink details (Supports both PipeWire and PulseAudio)
if command -v wpctl >/dev/null; then
    SINK_INFO=$(wpctl status | grep -A 5 "Sinks:" | grep "\*" | head -n1)
    VOL_STR=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
    
    # FIX: Replaced 'bc' with 'awk' for math, and added strict regex matching for the decimal
    VOL_PCT=$(echo "$VOL_STR" | grep -oP '\d+\.\d+' | awk '{print int($1*100)}')
    
    MUTED=false
    if [[ "$VOL_STR" == *"[MUTED]"* ]]; then MUTED=true; fi
    NAME=$(echo "$SINK_INFO" | sed -E 's/.*\* +[0-9]+. +//')
else
    DEFAULT_SINK=$(pactl info | grep "Default Sink" | cut -d: -f2 | xargs)
    VOL_PCT=$(pactl get-sink-volume "$DEFAULT_SINK" | grep -oP '\d+%' | head -n1 | tr -d '%')
    MUTE_STATE=$(pactl get-sink-mute "$DEFAULT_SINK" | awk '{print $2}')
    MUTED=false
    if [[ "$MUTE_STATE" == "yes" ]]; then MUTED=true; fi
    NAME=$(pactl list sinks | grep -A 20 "Name: $DEFAULT_SINK" | grep "Description:" | cut -d: -f2 | xargs)
fi

[ -z "$VOL_PCT" ] && VOL_PCT="0"
[ -z "$NAME" ] && NAME="Audio Output"

# Basic heuristics for Port/Icon
PORT_INFO="Line Out"
ICON="󰓃"
if echo "$NAME" | grep -qi "headphone\|headset"; then
    PORT_INFO="Headphones"
    ICON="󰋋"
fi

# We map unmuted to "power on", muted to "power off" for UI coherency
POWER="on"
if [ "$MUTED" = true ]; then POWER="off"; fi

CONNECTED_JSON=$(jq -n \
    --arg id "audio_default" \
    --arg name "$NAME" \
    --arg icon "$ICON" \
    --arg vol "${VOL_PCT}%" \
    --arg port "$PORT_INFO" \
    --argjson muted "$MUTED" \
    '{id: $id, name: $name, icon: $icon, volume: $vol, port: $port, muted: $muted}')

echo $(jq -n \
    --arg power "$POWER" \
    --argjson connected "$CONNECTED_JSON" \
    '{power: $power, connected: $connected}')
