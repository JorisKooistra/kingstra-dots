#!/usr/bin/env bash
# Eigen Kingstra-picker; skwd blijft uitsluitend de renderer.
set -euo pipefail
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
picker="$config_home/quickshell/WallpaperPicker.qml"
runtime="${XDG_RUNTIME_DIR:-/tmp}"

[[ -f "$picker" ]] || { echo "WallpaperPicker.qml ontbreekt: $picker" >&2; exit 1; }
# Serialiseer ook twee bijna gelijktijdige sneltoetsen vóór het IPC klaarstaat.
exec 9>"$runtime/kingstra-wallpaper-picker-$UID.lock"
flock -n 9 || exit 0
if quickshell ipc -p "$picker" call picker close >/dev/null 2>&1; then
    exit 0
fi

# Compile our own shader when its source changes; generated binaries stay in
# the cache, never alongside the symlinked source files in the repository.
shader_dir="${XDG_CACHE_HOME:-$HOME/.cache}/kingstra/wallpaper-picker"
export KINGSTRA_PICKER_SHADER="$shader_dir/card.frag.qsb"
export KINGSTRA_PICKER_VERTEX_SHADER="$shader_dir/card.vert.qsb"
for shader_name in card.frag card.vert; do
    shader_source="$config_home/quickshell/wallpaper/$shader_name"
    shader_target="$shader_dir/$shader_name.qsb"
    if [[ ! -s "$shader_target" || "$shader_source" -nt "$shader_target" ]]; then
        mkdir -p "$shader_dir"
        shader_tmp="$(mktemp "$shader_dir/.card.XXXXXX.qsb")"
        qsb_bin="$(command -v qsb || printf '%s' /usr/lib/qt6/bin/qsb)"
        if ! "$qsb_bin" --glsl '100 es,120,150' -o "$shader_tmp" "$shader_source"; then
            rm -f -- "$shader_tmp"
            exit 1
        fi
        mv -- "$shader_tmp" "$shader_target"
    fi
done

export KINGSTRA_PICKER_MONITOR="$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name' | head -1 || true)"
# Qt receives Hyprland's already-scaled angle delta (e.g. 162 instead of 120).
# Undo that scale for discrete tile steps; touchpad pixel gestures stay continuous.
export KINGSTRA_PICKER_SCROLL_FACTOR="$(hyprctl getoption input:scroll_factor -j 2>/dev/null | jq -r '.float | select(type == "number" and . > 0)' || true)"
export QML_IMPORT_PATH="$HOME/.local/lib/qml${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}"
export QS_APP_ID=kingstra-wallpaper-picker
setsid nohup quickshell --no-duplicate -p "$picker" >"$runtime/kingstra-wallpaper-picker.log" 2>&1 < /dev/null 9>&- &
