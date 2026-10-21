#!/usr/bin/env bash
# Super+T: toggle floating and remember the choice per app class, so the next
# window of that app opens the same way. The list is read by lua/rules.lua.
set -u

DISPATCH="$(dirname "${BASH_SOURCE[0]}")/hypr-dispatch.sh"
FLOAT_STATE="${KINGSTRA_FLOAT_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/kingstra/floating-apps}"

active_json="$(hyprctl activewindow -j 2>/dev/null || true)"
[[ -n "$active_json" && "$active_json" != "null" ]] || exit 0

win_class="$(printf '%s' "$active_json" | jq -r '.class // ""' 2>/dev/null)"
win_title="$(printf '%s' "$active_json" | jq -r '.title // ""' 2>/dev/null)"
win_floating="$(printf '%s' "$active_json" | jq -r '.floating // false' 2>/dev/null)"

# Quickshell windows must stay floating.
if [[ "$win_class" == "org.quickshell" || "$win_title" == "qs-master" ]]; then
    if [[ "$win_floating" != "true" ]]; then
        "$DISPATCH" togglefloating >/dev/null 2>&1 || true
    fi
    exit 0
fi

"$DISPATCH" togglefloating >/dev/null 2>&1 || true

[[ -n "$win_class" && "$win_class" != *$'\n'* ]] || exit 0

lua_quote() {
    local value="${1:-}"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '"%s"' "$value"
}

# Same escaping and rule name as rules.lua, so a reload yields the same rule.
class_regex="^$(printf '%s' "$win_class" | sed 's/[][\\^$.*+?(){}|-]/\\&/g')\$"
rule_name="remember-float-$(printf '%s' "$win_class" | sed 's/[^[:alnum:]]/-/g')"

mkdir -p "$(dirname "$FLOAT_STATE")" 2>/dev/null || exit 0
touch "$FLOAT_STATE" 2>/dev/null || exit 0
was_remembered=false
grep -Fxq -- "$win_class" "$FLOAT_STATE" && was_remembered=true

tmp_file="$(mktemp "${FLOAT_STATE}.tmp.XXXXXX")" || exit 0
grep -Fxv -- "$win_class" "$FLOAT_STATE" > "$tmp_file" || true
if [[ "$win_floating" != "true" ]]; then
    printf '%s\n' "$win_class" >> "$tmp_file"
    now_float=true
else
    now_float=false
fi
mv -f -- "$tmp_file" "$FLOAT_STATE"

# Apply to new windows in this session too. A later rule with the same match
# overrides an earlier one, so float = false undoes a remembered float.
if [[ "$now_float" == "true" || "$was_remembered" == "true" ]]; then
    hyprctl eval "hl.window_rule({ name = $(lua_quote "$rule_name"), match = { class = $(lua_quote "$class_regex") }, float = $now_float })" \
        >/dev/null 2>&1 || true
fi
