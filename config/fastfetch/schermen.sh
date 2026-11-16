#!/usr/bin/env bash
# Schermregel voor fastfetch: gelijke schermen samengevoegd,
# bv. "3× 1920×1080 @ 100 Hz", verschillende schermen naast elkaar.
json=$(hyprctl monitors -j 2>/dev/null) || json=""
if [[ -n "$json" ]] && command -v jq >/dev/null 2>&1; then
    out=$(printf '%s' "$json" | jq -r '
        map("\(.width)×\(.height) @ \(.refreshRate | round) Hz")
        | group_by(.) | sort_by(-length)
        | map(if length > 1 then "\(length)× \(.[0])" else .[0] end)
        | join(" · ")' 2>/dev/null)
fi
printf '%s' "${out:-onbekend}"
