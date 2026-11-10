#!/usr/bin/env bash
# Privacy-stipjes voor het Kingstra-eiland: gebruikt iets nu de microfoon,
# de camera of een schermopname? Eén JSON-regel, goedkoop genoeg om elke
# paar seconden te draaien.
set -u

mic=false
camera=false
recording=false

# Microfoon: een actieve opname-stream.
if command -v pactl >/dev/null 2>&1 && [[ -n "$(pactl list short source-outputs 2>/dev/null)" ]]; then
    mic=true
fi

# Camera: een proces met /dev/video* open. Geen camera, dan niets zoeken.
# Liefst fuser; de oude `find /proc/*/fd` liep elke 3 s door alle processen
# en brak geregeld af (SIGABRT, coredumps) als een proces tussendoor stopte.
shopt -s nullglob
videos=(/dev/video*)
shopt -u nullglob
if (( ${#videos[@]} )); then
    if command -v fuser >/dev/null 2>&1; then
        fuser -s "${videos[@]}" 2>/dev/null && camera=true
    else
        for fd in /proc/[0-9]*/fd/*; do
            [[ "$(readlink "$fd" 2>/dev/null)" == /dev/video* ]] && { camera=true; break; }
        done
    fi
fi

if pgrep -x 'wf-recorder|wl-screenrec|gpu-screen-recorder|obs' >/dev/null 2>&1; then
    recording=true
fi

# Scherm delen: xdg-desktop-portal-hyprland maakt per deelsessie een
# PipeWire-stroom "xdph-streaming-…"; zolang die bestaat, kijkt iemand mee.
sharing=false
if command -v pw-cli >/dev/null 2>&1 && pw-cli ls Node 2>/dev/null | grep -q 'xdph-streaming-'; then
    sharing=true
fi

printf '{"mic":%s,"camera":%s,"recording":%s,"sharing":%s}\n' "$mic" "$camera" "$recording" "$sharing"
