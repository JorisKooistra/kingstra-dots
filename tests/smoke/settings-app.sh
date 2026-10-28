#!/usr/bin/env bash
# Instellingen is een eigen app: eigen quickshell-proces met app-id
# kingstra-settings, niet meer in de bar. Controleert de bedrading en het
# startgedrag van settings-app.sh met nep-pgrep/quickshell/setsid.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
QS="$REPO_ROOT/config/quickshell"
SCRIPTS="$REPO_ROOT/config/hypr/scripts"
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

grep -q '^//@ pragma AppId kingstra-settings$' "$QS/SettingsApp.qml" || fail "SettingsApp.qml mist AppId-pragma"
grep -q 'SettingsWindow' "$QS/SettingsApp.qml" || fail "SettingsApp.qml laadt SettingsWindow niet"
if grep -q 'settings/SettingsWindow.qml' "$QS/TopBar.qml"; then
    fail "TopBar.qml laadt de instellingen nog in het bar-proces"
fi
grep -q 'class = "^kingstra-settings\$"' "$REPO_ROOT/config/hypr/lua/rules.lua" || fail "geen Hyprland-regel voor kingstra-settings"

# qs_manager moet instellingen afhandelen vóór de watchdog die de bar start.
settings_line="$(grep -n 'settings-app.sh' "$SCRIPTS/qs_manager.sh" | head -1 | cut -d: -f1)"
watchdog_line="$(grep -n 'QS_PID=\$(pgrep' "$SCRIPTS/qs_manager.sh" | head -1 | cut -d: -f1)"
[[ -n "$settings_line" && -n "$watchdog_line" && "$settings_line" -lt "$watchdog_line" ]] \
    || fail "qs_manager.sh stuurt instellingen niet vóór de watchdog naar settings-app.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home/.config/quickshell"
touch "$tmp/home/.config/quickshell/SettingsApp.qml"
cat > "$tmp/bin/pgrep" <<'EOF'
#!/usr/bin/env bash
[[ -f "$FAKE_RUNNING" ]]
EOF
cat > "$tmp/bin/setsid" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == "-f" ]] && shift
"$@"
EOF
cat > "$tmp/bin/quickshell" <<'EOF'
#!/usr/bin/env bash
printf '%s|%s|%s\n' "$*" "${QS_APP_ID:-}" "${KINGSTRA_SETTINGS_PAGE:-}" >> "$FAKE_LOG"
EOF
chmod +x "$tmp/bin/"*

run_app() {
    HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/home/.config" PATH="$tmp/bin:$PATH" \
        FAKE_RUNNING="$tmp/running" FAKE_LOG="$tmp/log" bash "$SCRIPTS/settings-app.sh" "$@"
}

request="/tmp/kingstra-settings-request"
before="$(cat "$request" 2>/dev/null || true)"

# Niet actief: start een eigen proces met de pagina in de omgeving.
run_app open thema
grep -q -- "--no-duplicate -p $tmp/home/.config/quickshell/SettingsApp.qml|kingstra-settings|thema" "$tmp/log" \
    || fail "settings-app.sh start de app niet met app-id en pagina: $(cat "$tmp/log")"

# Niet actief + close: niets starten.
: > "$tmp/log"
run_app close
[[ ! -s "$tmp/log" ]] || fail "close start onterecht een proces"

# Actief: verzoek via de request-file, geen tweede proces.
touch "$tmp/running"
run_app toggle geluid
[[ ! -s "$tmp/log" ]] || fail "draaiende app krijgt een tweede proces"
grep -q '^toggle:geluid:[0-9]*$' "$request" || fail "request-file niet geschreven: $(cat "$request")"
if [[ -n "$before" ]]; then printf '%s\n' "$before" > "$request"; fi

printf 'OK: instellingen draaien als eigen app\n'
