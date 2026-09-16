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
        # default, so persist it in WirePlumber and move every running stream.
        # VAL is the PulseAudio node name; older callers may still pass only it.
        PULSE_NAME="${VAL:-$ID}"
        if [[ "$ID" =~ ^[0-9]+$ ]] && command -v wpctl >/dev/null 2>&1; then
            wpctl set-default "$ID" || exit 1
        fi
        case "$TYPE" in
            sink)
                pactl set-default-sink "$PULSE_NAME" || exit 1
                while read -r stream_id _; do
                    [[ -n "$stream_id" ]] && pactl move-sink-input "$stream_id" "$PULSE_NAME" 2>/dev/null || true
                done < <(pactl list short sink-inputs)
                ;;
            source)
                pactl set-default-source "$PULSE_NAME" || exit 1
                while read -r stream_id _; do
                    [[ -n "$stream_id" ]] && pactl move-source-output "$stream_id" "$PULSE_NAME" 2>/dev/null || true
                done < <(pactl list short source-outputs)
                ;;
            *) exit 2 ;;
        esac
        ;;
    set-port)
        [[ "$TYPE" == "sink" && -n "$VAL" ]] || exit 2
        pactl set-sink-port "$ID" "$VAL"
        ;;
    test-sound)
        [[ "$TYPE" == "sink" ]] || exit 2
        pactl set-sink-mute "$ID" false
        paplay --device="$ID" /usr/share/sounds/freedesktop/stereo/audio-volume-change.oga
        ;;
    move-stream)
        [[ "$TYPE" == "sink-input" && -n "$VAL" ]] || exit 2
        pactl move-sink-input "$ID" "$VAL"
        ;;
    *) exit 2 ;;
esac
