#!/usr/bin/env bash
# kingstra-games vindt Steam, Heroic, Lutris en desktop-games in een nep-HOME,
# laat Proton en launchers weg en sorteert op laatst gespeeld.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/config/shared/scripts/kingstra-games"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
home="$work/home"

steam="$home/.local/share/Steam"
mkdir -p "$steam/steamapps" "$steam/appcache/librarycache/620/abc" "$work/lib2/steamapps"
cat > "$steam/steamapps/libraryfolders.vdf" <<EOF
"libraryfolders"
{
	"0" { "path" "$steam" }
	"1" { "path" "$work/lib2" }
}
EOF
acf() { printf '"AppState"\n{\n\t"appid"\t\t"%s"\n\t"name"\t\t"%s"\n\t"StateFlags"\t\t"%s"\n\t"LastPlayed"\t\t"%s"\n}\n' "$2" "$3" "$4" "$5" > "$1/steamapps/appmanifest_$2.acf"; }
acf "$steam" 620 "Portal 2" 4 1700000300
acf "$steam" 1493710 "Proton Experimental" 4 0
acf "$work/lib2" 400 "Portal" 6 1700000100
acf "$work/lib2" 999 "Half gedownload" 1026 0
acf "$work/lib2" 998 "Nog niet" 2 0
touch "$steam/appcache/librarycache/620/abc/library_600x900.jpg"

heroic="$home/.config/heroic"
mkdir -p "$heroic/store_cache" "$heroic/legendaryConfig/legendary" "$heroic/gog_store"
echo '{"library":[{"app_name":"Fortnite","title":"Fortnite","art_square":"https://cdn/fn.jpg"},{"app_name":"ABZU","title":"ABZU"}]}' > "$heroic/store_cache/legendary_library.json"
echo '{"games":[{"app_name":"1207658924","title":"Unreal Tournament","art_square":"https://cdn/ut.jpg"}]}' > "$heroic/store_cache/gog_library.json"
echo '{"Fortnite":{"title":"Fortnite","install_path":"/x"}}' > "$heroic/legendaryConfig/legendary/installed.json"
echo '{"installed":[{"appName":"1207658924","platform":"linux"}]}' > "$heroic/gog_store/installed.json"

apps="$home/.local/share/applications"
mkdir -p "$apps"
printf '[Desktop Entry]\nType=Application\nName=SuperTux\nExec=supertux2 %%U\nIcon=supertux\nCategories=Game;ArcadeGame;\n' > "$apps/supertux.desktop"
printf '[Desktop Entry]\nType=Application\nName=Steam\nExec=steam %%U\nCategories=Game;\n' > "$apps/steam.desktop"
printf '[Desktop Entry]\nType=Application\nName=Portal 2\nExec=steam steam://rungameid/620\nCategories=Game;\n' > "$apps/Portal 2.desktop"
printf '[Desktop Entry]\nType=Application\nName=Teksteditor\nExec=gedit\nCategories=Utility;\n' > "$apps/gedit.desktop"

python3 - "$home/.local/share/lutris/pga.db" <<'PY'
import sqlite3, sys, os
os.makedirs(os.path.dirname(sys.argv[1]), exist_ok=True)
con = sqlite3.connect(sys.argv[1])
con.execute("CREATE TABLE games (id INTEGER, name TEXT, slug TEXT, installed INTEGER, lastplayed INTEGER)")
con.executemany("INSERT INTO games VALUES (?,?,?,?,?)", [(3, "Diablo", "diablo", 1, 1700000200), (4, "Weg", "weg", 0, 0)])
con.commit()
PY

run() { env -i HOME="$home" PATH="$PATH" XDG_DATA_DIRS="$work/none" python3 "$SCRIPT" "$@"; }
out="$(run list)"
python3 - "$out" "$steam" <<'PY'
import json, sys
games = json.loads(sys.argv[1])
ids = [g["id"] for g in games]
want = ["steam:620", "lutris:3", "steam:400", "heroic:legendary:Fortnite", "desktop:supertux", "heroic:gog:1207658924"]
assert ids == want, f"volgorde/inhoud: {ids}"
by = {g["id"]: g for g in games}
assert by["steam:620"]["cover"].endswith("620/abc/library_600x900.jpg"), by["steam:620"]
assert by["steam:620"]["launch"] == ["steam", "steam://rungameid/620"]
assert by["heroic:legendary:Fortnite"]["cover"] == "https://cdn/fn.jpg"
assert by["heroic:gog:1207658924"]["title"] == "Unreal Tournament"
assert "runner=gog" in by["heroic:gog:1207658924"]["launch"][-1]
assert by["desktop:supertux"]["launch"] == ["supertux2"], by["desktop:supertux"]
assert by["lutris:3"]["launch"] == ["lutris", "lutris:rungameid/3"]
PY

# Starten noteert laatst gespeeld, zodat SuperTux bovenaan komt.
mkdir -p "$work/bin"
printf '#!/bin/sh\ntouch "%s/started"\n' "$work" > "$work/bin/supertux2"
chmod +x "$work/bin/supertux2"
env -i HOME="$home" PATH="$work/bin:$PATH" XDG_DATA_DIRS="$work/none" python3 "$SCRIPT" launch desktop:supertux
for _ in 1 2 3 4 5 6 7 8 9 10; do [[ -f "$work/started" ]] && break; sleep 0.1; done
[[ -f "$work/started" ]] || { echo "kingstra-games: launch startte niets" >&2; exit 1; }
first="$(run list | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["id"])')"
[[ "$first" == "desktop:supertux" ]] || { echo "kingstra-games: verwacht supertux bovenaan, kreeg $first" >&2; exit 1; }
if run launch steam:nope 2>/dev/null; then echo "kingstra-games: onbekende id moet falen" >&2; exit 1; fi

echo "kingstra-games: ok"
