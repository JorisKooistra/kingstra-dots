#!/usr/bin/env bash
# Apps echt sluiten: de lijst (standaard ChatGPT), toevoegen/verwijderen en
# dat de watcher na het laatste venster het proces van een lijst-app stopt,
# maar een app met nog een venster of buiten de lijst laat draaien.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/config/hypr/scripts/app-quit.sh"
work="$(mktemp -d)"
pids=()
cleanup() {
    local pid
    for pid in "${pids[@]}"; do { kill -KILL "$pid"; wait "$pid"; } 2>/dev/null || true; done
    rm -rf "$work"
}
trap cleanup EXIT

mkdir -p "$work/bin"
cat > "$work/bin/hyprctl" <<'FAKE'
#!/usr/bin/env bash
case "$1" in
    clients) cat "$FAKE_CLIENTS" ;;
    activewindow) cat "$FAKE_ACTIVE" ;;
esac
FAKE
chmod +x "$work/bin/hyprctl"
export PATH="$work/bin:$PATH" FAKE_CLIENTS="$work/clients.json" FAKE_ACTIVE="$work/active.json"
export KINGSTRA_CLOSE_FULLY_LIST="$work/close-fully.list" KINGSTRA_CLOSE_GRACE=0.2

fail() { printf 'app-quit: %s\n' "$*" >&2; exit 1; }

[[ "$(bash "$SCRIPT" list)" == "chatgpt" ]] || fail 'ChatGPT staat niet standaard op de lijst'
bash "$SCRIPT" matches "com.openai.ChatGPT" || fail 'chatgpt past niet op com.openai.ChatGPT'
! bash "$SCRIPT" matches "firefox" || fail 'firefox past ten onrechte'

bash "$SCRIPT" add "discord"
bash "$SCRIPT" add "Discord"
[[ "$(bash "$SCRIPT" list | tr '\n' ' ')" == "chatgpt discord " ]] || fail "toevoegen: $(bash "$SCRIPT" list)"
bash "$SCRIPT" remove "chatgpt"
[[ "$(bash "$SCRIPT" list | tr '\n' ' ')" == "discord " ]] || fail "verwijderen: $(bash "$SCRIPT" list)"
bash "$SCRIPT" remove "discord"
[[ -z "$(bash "$SCRIPT" list)" ]] || fail 'een lege lijst valt terug op de standaard'
bash "$SCRIPT" add "chatgpt"

printf '[{"class":"kitty","mapped":true,"pid":1},{"class":"ChatGPT","mapped":true,"pid":2},{"class":"kitty","mapped":true,"pid":1}]' > "$FAKE_CLIENTS"
[[ "$(bash "$SCRIPT" classes | tr '\n' ' ')" == "ChatGPT kitty " ]] || fail "open klassen: $(bash "$SCRIPT" classes)"

# Watcher: handle_close via een nep-socket is te veel; roep hem direct aan.
handle() { bash -c 'source <(sed "/^case \"\${1:-}\" in/,\$d" "$0"); handle_close "$1" "$2"' "$SCRIPT" "$@"; }

sleep 30 & chat=$!; pids+=("$chat")
printf '[]' > "$FAKE_CLIENTS"
handle "$chat" "ChatGPT"
sleep 0.3
! kill -0 "$chat" 2>/dev/null || fail 'lijst-app zonder vensters draait nog'

sleep 30 & other=$!; pids+=("$other")
handle "$other" "firefox"
kill -0 "$other" 2>/dev/null || fail 'app buiten de lijst is gestopt'

sleep 30 & busy=$!; pids+=("$busy")
printf '[{"class":"ChatGPT","mapped":true,"pid":%d}]' "$busy" > "$FAKE_CLIENTS"
handle "$busy" "ChatGPT"
kill -0 "$busy" 2>/dev/null || fail 'lijst-app met nog een venster is gestopt'

# Super+Shift+Q: het actieve venster echt afsluiten.
printf '{"class":"firefox","pid":%d}' "$other" > "$FAKE_ACTIVE"
bash "$SCRIPT" active
sleep 0.3
! kill -0 "$other" 2>/dev/null || fail 'Super+Shift+Q stopte het actieve proces niet'

echo "ok: apps echt sluiten"
