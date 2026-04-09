#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell"
CACHE_FILE="$CACHE_DIR/package_updates_count"
LOCK_FILE="$CACHE_DIR/package_updates.lock"
MAX_AGE_SECONDS=900

mkdir -p "$CACHE_DIR"

now="$(date +%s)"

read_cached_count() {
    if [[ -f "$CACHE_FILE" ]]; then
        awk '{print $2}' "$CACHE_FILE" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

cache_is_fresh() {
    [[ -f "$CACHE_FILE" ]] || return 1

    local cached_ts
    cached_ts="$(awk '{print $1}' "$CACHE_FILE" 2>/dev/null || echo "")"
    [[ "$cached_ts" =~ ^[0-9]+$ ]] || return 1

    (( now - cached_ts < MAX_AGE_SECONDS ))
}

compute_updates_count() {
    local raw=""
    local count=0

    if command -v yay >/dev/null 2>&1; then
        raw="$(timeout 25 yay -Qu 2>/dev/null || true)"
    elif command -v checkupdates >/dev/null 2>&1; then
        raw="$(timeout 25 checkupdates 2>/dev/null || true)"
    else
        echo "0"
        return 0
    fi

    count="$(printf "%s\n" "$raw" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')"
    [[ "$count" =~ ^[0-9]+$ ]] || count=0
    echo "$count"
}

if cache_is_fresh; then
    read_cached_count
    exit 0
fi

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    # Another process is already refreshing. Return stale (or zero) data.
    read_cached_count
    exit 0
fi

count="$(compute_updates_count)"
printf '%s %s\n' "$now" "$count" > "$CACHE_FILE"
echo "$count"
