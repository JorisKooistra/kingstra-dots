#!/usr/bin/env bash
# =============================================================================
# feedback.sh — korte melding rechtsboven (FeedbackToast), optioneel met
# een knop "Ongedaan maken".
# =============================================================================
# Gebruik:
#   feedback.sh [--undo "shell-commando"] [--undo-label tekst] ICOON TITEL [DETAIL] [TIMEOUT_MS]
#
# Het undo-commando draait via bash -lc met ~/.local/bin in PATH, dus
# "kingstra theme matte" werkt gewoon.
# =============================================================================
set -uo pipefail

undo=""
undo_label="Ongedaan maken"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --undo) undo="${2:-}"; shift 2 ;;
        --undo-label) undo_label="${2:-}"; shift 2 ;;
        *) break ;;
    esac
done

icon="${1:-󰄀}"
title="${2:-Klaar}"
detail="${3:-}"
timeout="${4:-}"
[[ "$timeout" =~ ^[0-9]+$ ]] || timeout=$([[ -n "$undo" ]] && echo 7000 || echo 2400)

token="$(date +%s%3N)$RANDOM"
tmp="$(mktemp /tmp/kingstra-feedback.json.XXXXXX)" || exit 0
jq -nc --arg token "$token" --arg icon "$icon" --arg title "$title" --arg detail "$detail" \
    --argjson timeout "$timeout" --arg undo "$undo" --arg undoLabel "$undo_label" \
    '{token:$token, icon:$icon, title:$title, detail:$detail, timeout:$timeout}
     + (if $undo != "" then {undo:$undo, undoLabel:$undoLabel} else {} end)' > "$tmp" \
    && mv -f "$tmp" /tmp/kingstra-feedback.json
