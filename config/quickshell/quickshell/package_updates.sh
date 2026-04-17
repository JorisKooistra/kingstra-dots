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
    local raw_repo=""
    local raw_aur=""
    local combined=""
    local count=0
    local status_repo=0
    local status_aur=0
    local aur_helper=""
    local repo_ok=false
    local aur_ok=false

    if command -v checkupdates >/dev/null 2>&1; then
        # checkupdates synchroniseert een tijdelijke package database. Daardoor
        # ziet de bar nieuwe repo-updates zonder dat de gebruiker eerst -Sy draait.
        set +e
        raw_repo="$(timeout "$QUERY_TIMEOUT_SECONDS" checkupdates 2>/dev/null)"
        status_repo=$?
        set -e
        if [[ $status_repo -eq 124 ]]; then
            return 1
        fi
        if [[ $status_repo -eq 0 || $status_repo -eq 2 ]]; then
            repo_ok=true
        else
            return 1
        fi
    elif command -v yay >/dev/null 2>&1; then
        # Fallback: dit leest alleen de lokale pacman database en kan dus
        # achterlopen totdat iets anders de package databases ververst.
        set +e
        raw_repo="$(timeout "$QUERY_TIMEOUT_SECONDS" yay -Qu 2>/dev/null)"
        status_repo=$?
        set -e
        if [[ $status_repo -eq 124 ]]; then
            return 1
        fi
        if [[ $status_repo -eq 0 ]]; then
            repo_ok=true
        else
            return 1
        fi
    elif command -v paru >/dev/null 2>&1; then
        # Zelfde fallback voor paru-gebruikers.
        set +e
        raw_repo="$(timeout "$QUERY_TIMEOUT_SECONDS" paru -Qu 2>/dev/null)"
        status_repo=$?
        set -e
        if [[ $status_repo -eq 124 ]]; then
            return 1
        fi
        if [[ $status_repo -eq 0 ]]; then
            repo_ok=true
        else
            return 1
        fi
    fi

    if command -v yay >/dev/null 2>&1; then
        aur_helper="yay"
    elif command -v paru >/dev/null 2>&1; then
        aur_helper="paru"
    fi

    if [[ -n "$aur_helper" ]]; then
        set +e
        raw_aur="$(timeout "$QUERY_TIMEOUT_SECONDS" "$aur_helper" -Qua 2>/dev/null)"
        status_aur=$?
        set -e
        if [[ $status_aur -eq 124 ]]; then
            return 1
        fi
        if [[ $status_aur -eq 0 ]]; then
            aur_ok=true
        fi
    fi

    if [[ "$repo_ok" != true && "$aur_ok" != true ]]; then
        echo "0"
        return 0
    fi

    # Combineer repo + AUR zodat teller gelijkloopt met `yay -Syu`.
    combined="$(printf "%s\n%s\n" "$raw_repo" "$raw_aur" | sed '/^[[:space:]]*$/d')"
    count="$(printf "%s\n" "$combined" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')"
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
