#!/usr/bin/env bash

set -u

ACTION="${1:-}"
TYPE="${2:-}"
ID="${3:-}"
VAL="${4:-}"

case "$TYPE" in
    sink|source|sink-input) ;;
    *) exit 2 ;;
esac

case "$ACTION" in
    set-volume)
        [[ "$VAL" =~ ^[0-9]{1,3}$ ]] || exit 2
        pactl "set-${TYPE}-volume" "$ID" "${VAL}%"
        ;;
    toggle-mute)
        pactl "set-${TYPE}-mute" "$ID" toggle
        ;;
    set-default)
        # PulseAudio-compatible clients do not consistently follow a changed
        # default, so move every running stream as part of the same action.
        case "$TYPE" in
            sink)
                pactl set-default-sink "$ID" || exit 1
                while read -r stream_id _; do
                    [[ -n "$stream_id" ]] && pactl move-sink-input "$stream_id" "$ID" 2>/dev/null || true
                done < <(pactl list short sink-inputs)
                ;;
            source)
                pactl set-default-source "$ID" || exit 1
                while read -r stream_id _; do
                    [[ -n "$stream_id" ]] && pactl move-source-output "$stream_id" "$ID" 2>/dev/null || true
                done < <(pactl list short source-outputs)
                ;;
            *) exit 2 ;;
        esac
        ;;
    *) exit 2 ;;
esac
