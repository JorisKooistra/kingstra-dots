#!/usr/bin/env bash
# Remembers the size and on-screen position of remembered floating apps (see
# togglefloating-safe.sh), so they reopen exactly as they closed. Hyprland
# reports no geometry on close and no event on resize, so the geometry is
# read on window events and a light poll while such a window is open, and
# stored whenever it changes. The position is stored as a
# percentage of the monitor, so the app reopens at the same spot on whichever
# monitor is active.
set -u

FLOAT_STATE="${KINGSTRA_FLOAT_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/kingstra/floating-apps}"
POLL_SECONDS=2

lua_quote() {
    local value="${1:-}"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '"%s"' "$value"
}

class_regex() {
    printf '^%s$' "$(printf '%s' "$1" | sed 's/[][\\^$.*+?(){}|-]/\\&/g')"
}

rule_name() {
    printf 'remember-float-%s' "$(printf '%s' "$1" | sed 's/[^[:alnum:]]/-/g')"
}

# remember_geometry CLASS W H XPCT YPCT: store and apply live, only for apps
# that are still on the floating list and only when the geometry changed.
remember_geometry() {
    local class="$1" size="$2 $3" move="$4% $5%" tmp_file
    [[ -f "$FLOAT_STATE" ]] || return 0
    awk -F '\t' -v c="$class" '$1 == c { found = 1 } END { exit !found }' "$FLOAT_STATE" || return 0
    grep -Fxq -- "$class"$'\t'"$size"$'\t'"$move" "$FLOAT_STATE" && return 0

    tmp_file="$(mktemp "${FLOAT_STATE}.tmp.XXXXXX")" || return 0
    awk -F '\t' -v OFS='\t' -v c="$class" -v s="$size" -v m="$move" \
        '$1 == c { print c, s, m; next } { print }' "$FLOAT_STATE" > "$tmp_file"
    mv -f -- "$tmp_file" "$FLOAT_STATE"

    hyprctl eval "hl.window_rule({ name = $(lua_quote "$(rule_name "$class")"), match = { class = $(lua_quote "$(class_regex "$class")") }, float = true, size = $(lua_quote "$size"), move = $(lua_quote "$move") })" \
        >/dev/null 2>&1 || true
}

declare -A cache=()

# Rebuild the cache: address -> class, size and position relative to its
# monitor, for floating windows of remembered apps.
refresh_cache() {
    cache=()
    [[ -s "$FLOAT_STATE" ]] || return 0
    local clients monitors addr rest
    clients="$(hyprctl clients -j 2>/dev/null)" || return 0
    monitors="$(hyprctl monitors -j 2>/dev/null)" || return 0
    while IFS=$'\t' read -r addr rest; do
        [[ -n "$addr" ]] || continue
        cache["${addr#0x}"]="$rest"
        store_entry "$rest"
    done < <(jq -r --rawfile list "$FLOAT_STATE" --argjson mons "$monitors" '
        ($list | split("\n") | map(split("\t")[0]) | map(select(. != ""))) as $classes
        | .[] | select(.floating and .mapped and (.class as $c | $classes | index($c)))
        | . as $w
        | ($mons | map(select(.id == $w.monitor)) | first) as $m
        | select($m != null)
        | (if ($m.transform % 2) == 1 then [$m.height, $m.width] else [$m.width, $m.height] end
           | map(. / $m.scale)) as $mon
        # Clamp to the monitor so the window always fits where it reopens.
        | [([$w.size[0], $mon[0]] | min | floor), ([$w.size[1], $mon[1]] | min | floor)] as $size
        | [$w.address, $w.class, $size[0], $size[1],
           ((($w.at[0] - $m.x) / $mon[0] * 100) | round | if . < 0 then 0 elif . > 99 then 99 else . end),
           ((($w.at[1] - $m.y) / $mon[1] * 100) | round | if . < 0 then 0 elif . > 99 then 99 else . end)]
        | @tsv' <<< "$clients" 2>/dev/null)
}

store_entry() {
    local class w h x y
    IFS=$'\t' read -r class w h x y <<< "$1"
    [[ -n "$y" ]] && remember_geometry "$class" "$w" "$h" "$x" "$y"
}

# The last poll may predate a quick resize; store what was seen last.
handle_close() {
    local entry="${cache[${1#0x}]:-}"
    [[ -n "$entry" ]] && store_entry "$entry"
    return 0
}

main() {
    if [[ "${1:-}" == "--remember" ]]; then
        shift
        remember_geometry "$@"
        exit 0
    fi

    command -v socat >/dev/null 2>&1 || exit 0
    command -v jq >/dev/null 2>&1 || exit 0
    [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || exit 0
    local socket="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
    for _ in {1..50}; do
        [[ -S "$socket" ]] && break
        sleep 0.1
    done
    [[ -S "$socket" ]] || exit 0

    refresh_cache
    local event status
    while true; do
        IFS= read -r -t "$POLL_SECONDS" event
        status=$?
        if (( status > 128 )); then
            # Resizes emit no event: poll only while a remembered float is open.
            (( ${#cache[@]} > 0 )) && refresh_cache
            continue
        fi
        (( status == 0 )) || break
        case "$event" in
            closewindow\>\>*)
                handle_close "${event#closewindow>>}"
                refresh_cache
                ;;
            openwindow\>\>*|changefloatingmode\>\>*|movewindow*|activewindowv2\>\>*)
                refresh_cache
                ;;
        esac
    done < <(socat -u "UNIX-CONNECT:$socket" - 2>/dev/null)
}

main "$@"
