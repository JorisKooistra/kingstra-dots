#!/usr/bin/env bash
# Run isolated worker tests and exercise launch/toggle without a live GUI.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
python3 "$root/tests/smoke/wallpaper-picker.py"
qml_runner="${QMLTESTRUNNER:-/usr/lib/qt6/bin/qmltestrunner}"
[[ -x "$qml_runner" ]] || qml_runner="$(command -v qmltestrunner6 || true)"
if [[ -x "$qml_runner" ]]; then
    QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software "$qml_runner" -input "$root/tests/smoke/qml/tst_wallpaper-picker.qml" -o -,txt
fi
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/config/quickshell/wallpaper" "$tmp/runtime"
touch "$tmp/config/quickshell/WallpaperPicker.qml" "$tmp/config/quickshell/wallpaper/card.frag" "$tmp/config/quickshell/wallpaper/card.vert"
cat > "$tmp/bin/quickshell" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "ipc" ]]; then
    [[ -f "$FAKE_PICKER_RUNNING" ]] || exit 1
    rm -- "$FAKE_PICKER_RUNNING"
    exit 0
fi
printf '%s\n' "$KINGSTRA_PICKER_MONITOR" "$KINGSTRA_PICKER_SHADER" "$*" "$KINGSTRA_PICKER_SCROLL_FACTOR" > "$FAKE_PICKER_LOG"
touch "$FAKE_PICKER_RUNNING"
EOF
cat > "$tmp/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == getoption ]]; then printf '%s\n' '{"float":1.35}'; else
    printf '%s\n' '[{"name":"DP-1","focused":false},{"name":"DP-3","focused":true}]'
fi
EOF
cat > "$tmp/bin/qsb" <<'EOF'
#!/usr/bin/env bash
printf 'compiled\n' >> "$FAKE_SHADER_LOG"
while [[ $# -gt 0 ]]; do
    if [[ "$1" == "-o" ]]; then printf 'shader' > "$2"; exit 0; fi
    shift
done
exit 1
EOF
chmod +x "$tmp/bin/"*
export XDG_CONFIG_HOME="$tmp/config" XDG_CACHE_HOME="$tmp/cache" XDG_RUNTIME_DIR="$tmp/runtime"
export FAKE_PICKER_RUNNING="$tmp/running" FAKE_PICKER_LOG="$tmp/launch" FAKE_SHADER_LOG="$tmp/shader-log"
export PATH="$tmp/bin:$PATH"
bash "$root/config/hypr/scripts/wallpaper-picker-safe.sh"
for _ in {1..50}; do [[ -f "$tmp/running" ]] && break; sleep 0.02; done
[[ -f "$tmp/running" ]]
[[ "$(head -1 "$tmp/launch")" == 'DP-3' ]]
[[ "$(tail -1 "$tmp/launch")" == '1.35' ]]
[[ -s "$tmp/cache/kingstra/wallpaper-picker/card.frag.qsb" ]]
[[ "$(wc -l < "$tmp/shader-log")" == 2 ]]
# Second press closes the existing app and does not start another one.
cp "$tmp/launch" "$tmp/first-launch"
bash "$root/config/hypr/scripts/wallpaper-picker-safe.sh"
[[ ! -f "$tmp/running" ]]
cmp "$tmp/launch" "$tmp/first-launch"
# Reopening reuses the compiled shader.
bash "$root/config/hypr/scripts/wallpaper-picker-safe.sh"
for _ in {1..50}; do [[ -f "$tmp/running" ]] && break; sleep 0.02; done
[[ -f "$tmp/running" ]]
[[ "$(wc -l < "$tmp/shader-log")" == 2 ]]
echo 'ok: picker worker, focused monitor, toggle and shader cache'
