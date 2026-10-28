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

# Camera: een proces met /dev/video* open. Eén find, geen lus per fd.
if [[ -n "$(find /proc/[0-9]*/fd -maxdepth 1 -lname '/dev/video*' -print -quit 2>/dev/null)" ]]; then
    camera=true
fi

if pgrep -x 'wf-recorder|wl-screenrec|gpu-screen-recorder|obs' >/dev/null 2>&1; then
    recording=true
fi

printf '{"mic":%s,"camera":%s,"recording":%s}\n' "$mic" "$camera" "$recording"
