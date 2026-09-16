#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DISPATCH="$REPO_ROOT/config/hypr/scripts/hypr-dispatch.sh"

assert_dispatch() {
    local expected="$1"
    shift
    local actual
    actual="$(HYPR_DISPATCH_PRINT_ONLY=true "$DISPATCH" "$@")"
    if [[ "$actual" != "$expected" ]]; then
        printf 'Verkeerde dispatcher voor %s\nverwacht: %s\nactueel:  %s\n' "$*" "$expected" "$actual" >&2
        exit 1
    fi
}

assert_dispatch 'hl.dsp.focus({ workspace = "2" })' workspace 2
assert_dispatch 'hl.dsp.window.move({ workspace = "4", follow = false, window = "address:0xabc" })' \
    movetoworkspacesilent 4 address:0xabc
assert_dispatch 'hl.dsp.focus({ direction = "left" })' movefocus l
assert_dispatch 'hl.dsp.focus({ monitor = "right" })' focusmonitor right
assert_dispatch 'hl.dsp.dpms({ action = "disable" })' dpms off
assert_dispatch 'hl.dsp.window.float({ action = "toggle" })' togglefloating
assert_dispatch 'hl.dsp.workspace.toggle_special("spotify")' togglespecialworkspace spotify
assert_dispatch 'hl.dsp.cursor.move({ x = 120, y = -40 })' movecursor 120 -40

if rg -n 'hyprctl( --batch)? dispatch' "$REPO_ROOT/config" "$REPO_ROOT/installer" \
    | rg -v '[Nn]o hyprctl dispatch needed|Een enkele directe|old `hyprctl dispatch|tests/smoke'; then
    printf 'Oude hyprctl-dispatchsyntax gevonden\n' >&2
    exit 1
fi

printf 'Hyprland Lua dispatcher smoke test: OK\n'
