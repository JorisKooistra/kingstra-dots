#!/usr/bin/env bash
# Scroll sequentially through the current monitor's workspace group (10 per group),
# wrapping from the last workspace back to the first and vice versa.
set -euo pipefail

dir="${1:?Usage: workspace-scroll.sh next|prev}"

current="$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // 1')"
[[ "$current" =~ ^[0-9]+$ ]] || current=1

group_start=$(( ((current - 1) / 10) * 10 + 1 ))
group_end=$(( group_start + 9 ))

if [[ "$dir" == "next" ]]; then
    next=$(( current + 1 ))
    (( next > group_end )) && next=$group_start
else
    next=$(( current - 1 ))
    (( next < group_start )) && next=$group_end
fi

hyprctl dispatch workspace "$next"
