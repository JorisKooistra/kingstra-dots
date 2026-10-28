#!/usr/bin/env bash
# werkvlak-settings.py: standaardwaarden, grenzen, bewaren en live toepassen.
set -euo pipefail
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export XDG_CONFIG_HOME="$tmp/config"
cat > "$tmp/hyprctl" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$HYPR_LOG"
echo ok
SH
chmod +x "$tmp/hyprctl"
export HYPRCTL_BIN="$tmp/hyprctl" HYPR_LOG="$tmp/hypr.log"
helper=config/hypr/scripts/werkvlak-settings.py

python3 "$helper" get | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d=={"column_width":1.0,"max_per_cell":4,"snap":0.2}, d'
python3 "$helper" set column_width 0.5 >/dev/null
python3 "$helper" set max_per_cell 2 >/dev/null
python3 "$helper" set snap 0 >/dev/null
python3 - "$XDG_CONFIG_HOME/kingstra/werkvlak.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert d == {"column_width": 0.5, "max_per_cell": 2, "snap": 0.0}, d
PY
grep -q 'eval hl.config({ scrolling = { column_width = 0.5 } })' "$HYPR_LOG"
grep -q '__kingstra_spatial_config.*c.max_per_cell = 2' "$HYPR_LOG"
if python3 "$helper" set max_per_cell 9 2>/dev/null; then echo "out of range accepted" >&2; exit 1; fi
if python3 "$helper" set colour 1 2>/dev/null; then echo "unknown key accepted" >&2; exit 1; fi
echo '{"column_width": 7, "snap": "x"}' > "$XDG_CONFIG_HOME/kingstra/werkvlak.json"
python3 "$helper" get | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["column_width"]==1.0 and d["snap"]==0.2, d'

# De Lua-config leest dezelfde waarden bij het laden.
printf '{"column_width": 0.667, "max_per_cell": 3, "snap": 0.4}\n' > "$XDG_CONFIG_HOME/kingstra/werkvlak.json"
lua - <<'LUA'
local seen
_G.hl = { layout = { register = function() end }, on = function() end, dispatch = function() end, dsp = {} }
assert(loadfile("config/hypr/lua/spatial/init.lua"))()
local c = rawget(_G, "__kingstra_spatial_config")
assert(c and c.max_per_cell == 3 and math.abs(c.snap - 0.4) < 1e-9, "spatial overrides not loaded")
LUA
echo "Werkvlak settings smoke test: OK"
