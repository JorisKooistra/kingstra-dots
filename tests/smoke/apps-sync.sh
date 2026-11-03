#!/usr/bin/env bash
# kingstra-apps-sync: dagelijkse apps volgen het thema (zonder gsettings/code).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SYNC="$REPO_ROOT/config/shared/scripts/kingstra-apps-sync"
T="$(mktemp -d)"
trap 'rm -rf -- "$T"' EXIT
H="$T/home"
mkdir -p "$H/.config/quickshell" "$H/.config/kingstra/state" "$H/.config/Code/User" \
    "$H/.config/vesktop/settings" "$H/.config/spicetify/Themes/Matugen" \
    "$H/.vscode/extensions/kingstra.kingstra-theme-1.0.0/themes"

fail() { echo "FAIL: $*" >&2; exit 1; }
run() { HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_STATE_HOME="$H/.local/state" \
    XDG_DATA_HOME="$H/.local/share" python3 "$SYNC" --no-apply 2>/dev/null; }

cat > "$H/.config/quickshell/theme.json" <<'JSON'
{"theme":"paper","mode":"light","border_radius":24,"ui_font":"IBM Plex Sans","ui_font_size":12,
 "mono_font":"JetBrainsMono Nerd Font","mono_font_size":12,"icon_theme":"Papirus",
 "material":{"glow_intensity":0.0},"style_profile":{"density":"comfortable","outline_strength":0.2}}
JSON
printf '{\n  // eigen commentaar blijft\n  "editor.fontSize": 14,\n}\n' > "$H/.config/Code/User/settings.json"
echo '{"enabledThemes":["eigen.css"]}' > "$H/.config/vesktop/settings/settings.json"
echo 'body {}' > "$H/.config/spicetify/Themes/Matugen/user.css"

run
run   # tweede keer: idempotent

grep -q '^gtk-application-prefer-dark-theme=0$' "$H/.config/gtk-3.0/settings.ini" || fail "licht thema geeft geen lichte GTK"
grep -q '^gtk-theme-name=adw-gtk3$' "$H/.config/gtk-3.0/settings.ini" || fail "GTK3-thema niet licht"
grep -q '^gtk-font-name=IBM Plex Sans 11$' "$H/.config/gtk-4.0/settings.ini" || fail "letter volgt thema niet"
grep -q 'border-radius: 999px' "$H/.config/gtk-4.0/kingstra-shape.css" || fail "ronde vorm ontbreekt"
grep -q 'kingstra-card-radius: 20px' "$H/.local/state/kingstra/apps/firefox-shape.css" || fail "Firefox-vorm ontbreekt"
grep -q 'icon_theme=' "$H/.config/qt6ct/qt6ct.conf" || fail "qt6ct niet bijgewerkt"
grep -q '"workbench.colorTheme": "Kingstra Licht' "$H/.config/Code/User/settings.json" || fail "VS Code-thema niet gekozen"
grep -q 'eigen commentaar blijft' "$H/.config/Code/User/settings.json" || fail "VS Code-commentaar verloren"
python3 -c 'import json,sys; json.load(open(sys.argv[1]))' \
    "$H/.vscode/extensions/kingstra.kingstra-theme-1.0.0/package.json" || fail "VS Code package.json kapot"
grep -q 'kingstra.theme.css' "$H/.config/vesktop/settings/settings.json" || fail "Vesktop-thema niet aan"
grep -q 'eigen.css' "$H/.config/vesktop/settings/settings.json" || fail "eigen Vesktop-thema weg"
[[ "$(grep -c 'kingstra vorm >>>' "$H/.config/spicetify/Themes/Matugen/user.css")" == 1 ]] || fail "Spotify-blok dubbel"

# --login zonder gsettings mag niets breken.
HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_STATE_HOME="$H/.local/state" \
    python3 "$SYNC" --login --no-apply 2>/dev/null || fail "--login faalt"
echo "apps-sync: ok"
