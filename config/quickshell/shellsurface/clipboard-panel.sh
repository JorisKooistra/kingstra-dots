#!/usr/bin/env bash
# Argument-safe bridge between the native Quickshell drawer and cliphist.
set -euo pipefail

feedback_file="/tmp/kingstra-feedback.json"
pins_file="${XDG_STATE_HOME:-$HOME/.local/state}/kingstra/clipboard-pins.json"

case "${1:-list}" in
    list)
        if ! command -v cliphist >/dev/null 2>&1; then
            printf '[]\n'
            exit 0
        fi
        cliphist list 2>/dev/null | head -n 80 | jq -Rsc 'split("\n") | map(select(length > 0))'
        ;;
    copy)
        entry="${2:-}"
        [[ -n "$entry" ]] || exit 0
        command -v cliphist >/dev/null 2>&1 || exit 1
        command -v wl-copy >/dev/null 2>&1 || exit 1
        printf '%s\n' "$entry" | cliphist decode | wl-copy

        # The native feedback toast observes this file. Write atomically so a
        # partial JSON document can never become visible.
        tmp="$(mktemp "$feedback_file.XXXXXX")"
        jq -n --arg token "$(date +%s%3N)-clipboard" \
            --arg icon "󰄀" --arg title "Klembord gekopieerd" \
            --arg body "Klaar om te plakken" --arg level "normal" \
            '{token: $token, icon: $icon, title: $title, body: $body, level: $level, timeout: 1800}' >"$tmp"
        mv "$tmp" "$feedback_file"
        ;;
    paste)
        # Kopiëren en meteen plakken in het venster dat daarna weer focus
        # krijgt. Terminals plakken met Ctrl+Shift+V.
        entry="${2:-}"
        [[ -n "$entry" ]] || exit 0
        if [[ "$entry" == pin:* ]]; then
            bash "$0" copy-pin "${entry#pin:}" || exit 1
        else
            printf '%s\n' "$entry" | cliphist decode | wl-copy || exit 1
        fi
        command -v wtype >/dev/null 2>&1 || exit 0
        # shellcheck disable=SC2016 # draait in de binnenste bash
        setsid -f bash -c '
            sleep 0.35
            class="$(hyprctl activewindow -j 2>/dev/null | jq -r ".class // empty" 2>/dev/null)"
            case "${class,,}" in
                kitty|foot|footclient|alacritty|org.wezfurlong.wezterm|com.mitchellh.ghostty|xterm-256color)
                    wtype -M ctrl -M shift v -m shift -m ctrl ;;
                *) wtype -M ctrl v -m ctrl ;;
            esac' >/dev/null 2>&1
        ;;
    pins)
        if [[ -f "$pins_file" ]]; then jq -c 'if type == "array" then . else [] end' "$pins_file" 2>/dev/null || printf '[]\n'
        else printf '[]\n'; fi
        ;;
    pin)
        # Alleen tekst; afbeeldingen blijven in de gewone geschiedenis.
        entry="${2:-}"
        [[ -n "$entry" ]] || exit 0
        text="$(printf '%s\n' "$entry" | cliphist decode)" || exit 1
        mkdir -p "$(dirname "$pins_file")"
        current="$(bash "$0" pins)"
        tmp="$(mktemp "$pins_file.XXXXXX")"
        printf '%s' "$current" | jq --arg t "$text" 'map(select(. != $t)) | [$t] + . | .[:30]' >"$tmp" && mv -f "$tmp" "$pins_file"
        ;;
    unpin)
        index="${2:-}"
        [[ "$index" =~ ^[0-9]+$ ]] || exit 2
        current="$(bash "$0" pins)"
        tmp="$(mktemp "$pins_file.XXXXXX")"
        printf '%s' "$current" | jq --argjson i "$index" 'del(.[$i])' >"$tmp" && mv -f "$tmp" "$pins_file"
        ;;
    copy-pin)
        index="${2:-}"
        [[ "$index" =~ ^[0-9]+$ ]] || exit 2
        bash "$0" pins | jq -r --argjson i "$index" '.[$i] // empty' | head -c -1 | wl-copy
        ;;
    *)
        printf 'Gebruik: %s {list|copy ENTRY|paste ENTRY|pins|pin ENTRY|unpin N|copy-pin N}\n' "${0##*/}" >&2
        exit 2
        ;;
esac
