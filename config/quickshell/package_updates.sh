#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell"
CACHE_FILE="$CACHE_DIR/package_updates_count"
LOCK_FILE="$CACHE_DIR/package_updates.lock"
MAX_AGE_SECONDS=900
QUERY_TIMEOUT_SECONDS=90

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
    local cached_count
    local max_age
    cached_ts="$(awk '{print $1}' "$CACHE_FILE" 2>/dev/null || echo "")"
    cached_count="$(awk '{print $2}' "$CACHE_FILE" 2>/dev/null || echo "")"
    [[ "$cached_ts" =~ ^[0-9]+$ ]] || return 1
    [[ "$cached_count" =~ ^[0-9]+$ ]] || return 1

    # Een 0-telling verversen we vaker om "vast op 0" te voorkomen.
    max_age=$MAX_AGE_SECONDS
    if [[ "$cached_count" -eq 0 ]]; then
        max_age=300
    fi

    (( now - cached_ts < max_age ))
}

compute_updates_count() {
    local raw=""
    local count=0
    local status=0
    local backend=""

    if command -v yay >/dev/null 2>&1; then
        backend="yay"
        set +e
        raw="$(timeout "$QUERY_TIMEOUT_SECONDS" yay -Qu 2>/dev/null)"
        status=$?
        set -e
    elif command -v checkupdates >/dev/null 2>&1; then
        backend="checkupdates"
        set +e
        raw="$(timeout "$QUERY_TIMEOUT_SECONDS" checkupdates 2>/dev/null)"
        status=$?
        set -e
    else
        echo "0"
        return 0
    fi

    # Timeout of harde fout: geef failure terug zodat caller cache kan behouden.
    if [[ $status -eq 124 ]]; then
        return 1
    fi

    # checkupdates geeft exitcode 2 bij "geen updates" (geen fout).
    if [[ -z "$raw" ]]; then
        if [[ "$backend" == "checkupdates" && $status -eq 2 ]]; then
            echo "0"
            return 0
        fi
        if [[ "$backend" == "yay" && $status -eq 0 ]]; then
            echo "0"
            return 0
        fi
        # Geen output + onverwachte status behandelen als mislukte meting.
        return 1
    fi

    count="$(printf "%s\n" "$raw" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')"
    [[ "$count" =~ ^[0-9]+$ ]] || count=0
    echo "$count"
    return 0
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

if count="$(compute_updates_count)"; then
    printf '%s %s\n' "$now" "$count" > "$CACHE_FILE"
    echo "$count"
    exit 0
fi

# Query faalde: bewaar bestaande cache i.p.v. foutief overschrijven met 0.
read_cached_count
