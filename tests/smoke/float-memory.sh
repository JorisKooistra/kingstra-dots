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
grep -Fq 'eval hl.window_rule({ name = "remember-float-org-gnome-Nautilus", match = { class = "^org\\.gnome\\.Nautilus$" }, float = true })' "$FAKE_LOG" \
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

printf 'Float memory smoke test: OK\n'
