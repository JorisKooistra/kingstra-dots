#!/usr/bin/env bash
# Super+T float memory: the toggle script keeps a per-class list and registers
# the matching Hyprland rule live.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/config/hypr/scripts/togglefloating-safe.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/bin"
cat > "$work/bin/hyprctl" <<'FAKE'
#!/usr/bin/env bash
case "$1" in
    activewindow) cat "$FAKE_WINDOW" ;;
    clients) cat "$FAKE_CLIENTS" ;;
    monitors) cat "$FAKE_MONITORS" ;;
    *) printf '%s\n' "$*" >> "$FAKE_LOG" ;;
esac
FAKE
chmod +x "$work/bin/hyprctl"
export PATH="$work/bin:$PATH" FAKE_WINDOW="$work/window.json" FAKE_LOG="$work/log"
export KINGSTRA_FLOAT_STATE="$work/state/floating-apps"

fail() { printf 'float-memory: %s\n' "$*" >&2; exit 1; }

printf '{"class":"org.gnome.Nautilus","title":"x","floating":false}' > "$FAKE_WINDOW"
bash "$SCRIPT"
grep -Fxq 'org.gnome.Nautilus' "$KINGSTRA_FLOAT_STATE" || fail 'class niet onthouden'
grep -Fq 'eval hl.window_rule({ name = "remember-float-org-gnome-Nautilus", match = { class = "^org\\.gnome\\.Nautilus$" }, float = true, size = "monitor_w*0.6 monitor_h*0.65", center = true })' "$FAKE_LOG" \
    || fail "verkeerde live-regel: $(cat "$FAKE_LOG")"

printf '{"class":"org.gnome.Nautilus","title":"x","floating":true}' > "$FAKE_WINDOW"
: > "$FAKE_LOG"
bash "$SCRIPT"
[[ ! -s "$KINGSTRA_FLOAT_STATE" ]] || fail 'class niet vergeten'
grep -Fq 'float = false' "$FAKE_LOG" || fail 'onthouden float niet ongedaan gemaakt'

# Tiling a window that was never remembered adds no rule.
printf '{"class":"firefox","title":"Save File","floating":true}' > "$FAKE_WINDOW"
: > "$FAKE_LOG"
bash "$SCRIPT"
! grep -q 'window_rule' "$FAKE_LOG" || fail 'onnodige regel voor niet-onthouden app'

printf '{"class":"org.quickshell","title":"x","floating":true}' > "$FAKE_WINDOW"
bash "$SCRIPT"
[[ ! -s "$KINGSTRA_FLOAT_STATE" ]] || fail 'Quickshell mag niet onthouden worden'

# Geometry on close: size plus position as a percentage of its monitor.
WATCH="$REPO_ROOT/config/hypr/scripts/float-memory-watch.sh"
printf 'kitty\nfirefox\n' > "$KINGSTRA_FLOAT_STATE"
export FAKE_CLIENTS="$work/clients.json" FAKE_MONITORS="$work/monitors.json"
cat > "$FAKE_MONITORS" <<'JSON'
[{"id":0,"x":0,"y":0,"width":1920,"height":1080,"scale":1,"transform":0},
 {"id":1,"x":1920,"y":0,"width":2880,"height":1800,"scale":1.5,"transform":0}]
JSON
cat > "$FAKE_CLIENTS" <<'JSON'
[{"address":"0xabc","class":"kitty","floating":true,"mapped":true,"monitor":1,"at":[2400,270],"size":[900,600]},
 {"address":"0xdef","class":"firefox","floating":false,"mapped":true,"monitor":0,"at":[0,0],"size":[1900,1060]},
 {"address":"0x123","class":"other","floating":true,"mapped":true,"monitor":0,"at":[10,10],"size":[300,300]}]
JSON
: > "$FAKE_LOG"
# shellcheck disable=SC1090,SC2154
( source <(sed '$d' "$WATCH"); refresh_cache; [[ ${#cache[@]} -eq 1 ]] || exit 1; handle_close abc ) \
    || fail 'cache bevat verkeerde vensters'
grep -Fxq $'kitty\t900 600\t25% 23%' "$KINGSTRA_FLOAT_STATE" \
    || fail "geometrie niet onthouden: $(cat -A "$KINGSTRA_FLOAT_STATE")"
grep -Fxq 'firefox' "$KINGSTRA_FLOAT_STATE" || fail 'andere apps aangetast'
grep -Fq 'size = "900 600", move = "monitor_w*0.25 monitor_h*0.23"' "$FAKE_LOG" || fail "geen live-regel: $(cat "$FAKE_LOG")"

# A large float keeps its size, it is stored as soon as it is seen (no close
# needed) and a window larger than its monitor is clamped to it.
cat > "$FAKE_CLIENTS" <<'JSON'
[{"address":"0xabc","class":"kitty","floating":true,"mapped":true,"monitor":0,"at":[10,10],"size":[1900,1040]},
 {"address":"0xdef","class":"firefox","floating":true,"mapped":true,"monitor":0,"at":[0,0],"size":[2500,1200]}]
JSON
: > "$FAKE_LOG"
# shellcheck disable=SC1090
( source <(sed '$d' "$WATCH"); refresh_cache ) || fail 'verversen mislukt'
grep -Fxq $'kitty\t1900 1040\t1% 1%' "$KINGSTRA_FLOAT_STATE" \
    || fail "grote maat niet onthouden: $(cat -A "$KINGSTRA_FLOAT_STATE")"
grep -Fxq $'firefox\t1920 1080\t0% 0%' "$KINGSTRA_FLOAT_STATE" \
    || fail "te grote maat niet begrensd: $(cat -A "$KINGSTRA_FLOAT_STATE")"
: > "$FAKE_LOG"
# shellcheck disable=SC1090
( source <(sed '$d' "$WATCH"); refresh_cache ) || fail 'verversen mislukt'
[[ ! -s "$FAKE_LOG" ]] || fail "ongewijzigde maat opnieuw toegepast: $(cat "$FAKE_LOG")"

# Toggling to tiled forgets the app including its geometry.
printf '{"class":"kitty","title":"x","floating":true}' > "$FAKE_WINDOW"
bash "$SCRIPT"
! grep -q '^kitty' "$KINGSTRA_FLOAT_STATE" || fail 'kitty met geometrie niet vergeten'

printf 'Float memory smoke test: OK\n'
