#!/usr/bin/env bash

selection="$({ cliphist list 2>/dev/null || true; } | walker --stdin --dmenu 2>/dev/null)"

[[ -n "$selection" ]] || exit 0

printf '%s' "$selection" | cliphist decode | wl-copy
