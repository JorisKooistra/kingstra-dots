#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell"
CACHE_FILE="$CACHE_DIR/package_updates_status"
LEGACY_CACHE_FILE="$CACHE_DIR/package_updates_count"
LOCK_FILE="$CACHE_DIR/package_updates.lock"
MAX_AGE_SECONDS=900
QUERY_TIMEOUT_SECONDS=90
OUTPUT_MODE="count"
FORCE_REFRESH=false

for arg in "$@"; do
    case "$arg" in
        --json) OUTPUT_MODE="json" ;;
        --refresh) FORCE_REFRESH=true ;;
        *)
            printf 'Gebruik: %s [--json] [--refresh]\n' "${0##*/}" >&2
            exit 2
            ;;
    esac
done

mkdir -p "$CACHE_DIR"

now="$(date +%s)"

valid_cache_line() {
    local ts="${1:-}"
    local total="${2:-}"
    local packages="${3:-}"
    local flatpaks="${4:-}"
    local dotfiles="${5:-}"
    local dotfiles_commits="${6:-}"

    [[ "$ts" =~ ^[0-9]+$ ]] \
        && [[ "$total" =~ ^[0-9]+$ ]] \
        && [[ "$packages" =~ ^[0-9]+$ ]] \
        && [[ "$flatpaks" =~ ^[0-9]+$ ]] \
        && [[ "$dotfiles" =~ ^[0-9]+$ ]] \
        && [[ "$dotfiles_commits" =~ ^[0-9]+$ ]]
}

read_cache_fields() {
    local ts=0 total=0 packages=0 flatpaks=0 dotfiles=0 dotfiles_commits=0

    if [[ -f "$CACHE_FILE" ]]; then
        read -r ts total packages flatpaks dotfiles dotfiles_commits < "$CACHE_FILE" || true
    elif [[ -f "$LEGACY_CACHE_FILE" ]]; then
        read -r ts total < "$LEGACY_CACHE_FILE" || true
        packages="$total"
    fi

    if ! valid_cache_line "$ts" "$total" "$packages" "$flatpaks" "$dotfiles" "$dotfiles_commits"; then
        ts=0
        total=0
        packages=0
        flatpaks=0
        dotfiles=0
        dotfiles_commits=0
    fi

    printf '%s %s %s %s %s %s\n' \
        "$ts" "$total" "$packages" "$flatpaks" "$dotfiles" "$dotfiles_commits"
}

emit_fields() {
    local ts="$1"
    local total="$2"
    local packages="$3"
    local flatpaks="$4"
    local dotfiles="$5"
    local dotfiles_commits="$6"

    if [[ "$OUTPUT_MODE" == "json" ]]; then
        printf '{"timestamp":%s,"total":%s,"packages":%s,"flatpak":%s,"dotfiles":%s,"dotfiles_commits":%s}\n' \
            "$ts" "$total" "$packages" "$flatpaks" "$dotfiles" "$dotfiles_commits"
    else
        printf '%s\n' "$total"
    fi
}

emit_cached() {
    local fields
    fields="$(read_cache_fields)"
    # De velden zijn hierboven als uitsluitend niet-negatieve integers gevalideerd.
    # shellcheck disable=SC2086
    emit_fields $fields
}

cache_is_fresh() {
    [[ "$FORCE_REFRESH" == false && -f "$CACHE_FILE" ]] || return 1

    local ts total packages flatpaks dotfiles dotfiles_commits max_age
    read -r ts total packages flatpaks dotfiles dotfiles_commits < "$CACHE_FILE" || return 1
    valid_cache_line "$ts" "$total" "$packages" "$flatpaks" "$dotfiles" "$dotfiles_commits" || return 1

    # Een lege teller wordt vaker opnieuw gecontroleerd, zodat 0 niet lang
    # blijft staan nadat repositories nieuwe metadata publiceren.
    max_age=$MAX_AGE_SECONDS
    if [[ "$total" -eq 0 ]]; then
        max_age=300
    fi

    (( now - ts < max_age ))
}

resolve_dotfiles_repo() {
    local marker="${XDG_DATA_HOME:-$HOME/.local/share}/kingstra/install-complete"
    local repo=""
    local script_path=""

    if [[ -f "$marker" ]]; then
        repo="$(sed -n 's/^Repo:[[:space:]]*//p' "$marker" | head -n 1)"
    fi

    if [[ -z "$repo" ]]; then
        script_path="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || true)"
        if [[ -n "$script_path" ]]; then
            repo="$(cd "$(dirname "$script_path")/../.." 2>/dev/null && pwd -P || true)"
        fi
    fi

    [[ -n "$repo" && -d "$repo/.git" ]] || return 1
    printf '%s\n' "$repo"
}

count_package_updates() {
    local raw_repo=""
    local raw_aur=""
    local status_repo=0
    local status_aur=0
    local aur_helper=""
    local repo_ok=false
    local aur_ok=false

    if command -v checkupdates >/dev/null 2>&1; then
        set +e
        raw_repo="$(timeout "$QUERY_TIMEOUT_SECONDS" checkupdates 2>/dev/null)"
        status_repo=$?
        set -e
        if [[ $status_repo -eq 0 || $status_repo -eq 2 ]]; then
            repo_ok=true
        else
            return 1
        fi
    elif command -v yay >/dev/null 2>&1; then
        set +e
        raw_repo="$(timeout "$QUERY_TIMEOUT_SECONDS" yay -Qu 2>/dev/null)"
        status_repo=$?
        set -e
        [[ $status_repo -eq 0 ]] || return 1
        repo_ok=true
    elif command -v paru >/dev/null 2>&1; then
        set +e
        raw_repo="$(timeout "$QUERY_TIMEOUT_SECONDS" paru -Qu 2>/dev/null)"
        status_repo=$?
        set -e
        [[ $status_repo -eq 0 ]] || return 1
        repo_ok=true
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
        if [[ $status_aur -eq 0 ]]; then
            aur_ok=true
        elif [[ $status_aur -eq 124 ]]; then
            return 1
        fi
    fi

    if [[ "$repo_ok" != true && "$aur_ok" != true ]]; then
        printf '0\n'
        return 0
    fi

    # Unieke pakketnamen voorkomen dubbeltelling wanneer een helper dezelfde
    # regel via zowel -Qu als -Qua rapporteert.
    printf '%s\n%s\n' "$raw_repo" "$raw_aur" \
        | awk 'NF { print $1 }' \
        | sort -u \
        | wc -l \
        | tr -d ' '
}

count_flatpak_updates() {
    local raw=""
    local status=0

    if ! command -v flatpak >/dev/null 2>&1; then
        printf '0\n'
        return 0
    fi

    set +e
    raw="$(timeout "$QUERY_TIMEOUT_SECONDS" flatpak remote-ls --updates --columns=application 2>/dev/null)"
    status=$?
    set -e
    [[ $status -eq 0 ]] || return 1

    printf '%s\n' "$raw" \
        | sed '/^[[:space:]]*$/d' \
        | sort -u \
        | wc -l \
        | tr -d ' '
}

count_dotfiles_updates() {
    local repo=""
    local branch=""
    local upstream=""
    local behind=0

    repo="$(resolve_dotfiles_repo 2>/dev/null || true)"
    if [[ -z "$repo" ]] || ! command -v git >/dev/null 2>&1; then
        printf '0\n'
        return 0
    fi

    branch="$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
    [[ -n "$branch" ]] || {
        printf '0\n'
        return 0
    }

    timeout "$QUERY_TIMEOUT_SECONDS" git -C "$repo" fetch --quiet origin "$branch" 2>/dev/null || return 1

    upstream="$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
    if [[ -z "$upstream" ]] && git -C "$repo" rev-parse --verify --quiet "origin/$branch" >/dev/null; then
        upstream="origin/$branch"
    fi
    if [[ -z "$upstream" ]]; then
        printf '0\n'
        return 0
    fi

    behind="$(git -C "$repo" rev-list --count "HEAD..$upstream" 2>/dev/null || echo 0)"
    [[ "$behind" =~ ^[0-9]+$ ]] || behind=0
    printf '%s\n' "$behind"
}

if cache_is_fresh; then
    emit_cached
    exit 0
fi

exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    # Een ander scherm/proces is al bezig. Geef intussen de laatste geldige
    # telling terug in plaats van meerdere netwerkchecks te starten.
    emit_cached
    exit 0
fi

packages="$(count_package_updates)" || {
    emit_cached
    exit 0
}
flatpaks="$(count_flatpak_updates)" || {
    emit_cached
    exit 0
}
dotfiles_commits="$(count_dotfiles_updates)" || {
    emit_cached
    exit 0
}

[[ "$packages" =~ ^[0-9]+$ ]] || packages=0
[[ "$flatpaks" =~ ^[0-9]+$ ]] || flatpaks=0
[[ "$dotfiles_commits" =~ ^[0-9]+$ ]] || dotfiles_commits=0

# Dotfiles tellen als één actie in de badge; het exacte aantal commits staat
# apart in de tooltip/status-JSON.
dotfiles=0
if [[ "$dotfiles_commits" -gt 0 ]]; then
    dotfiles=1
fi
total=$((packages + flatpaks + dotfiles))

tmp_file="${CACHE_FILE}.tmp.$$"
printf '%s %s %s %s %s %s\n' \
    "$now" "$total" "$packages" "$flatpaks" "$dotfiles" "$dotfiles_commits" > "$tmp_file"
mv -f "$tmp_file" "$CACHE_FILE"
printf '%s %s\n' "$now" "$total" > "$LEGACY_CACHE_FILE"

emit_fields "$now" "$total" "$packages" "$flatpaks" "$dotfiles" "$dotfiles_commits"
