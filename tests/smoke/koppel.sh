#!/usr/bin/env bash
# Smoke-test kingstra-koppel: klembord heen en terug zonder echo-lus, en
# bestanden sturen. ssh/wl-paste/wl-copy/notify-send zijn stubs; de "andere
# machine" is een tweede HOME in een tijdelijke map.
set -euo pipefail
# Nooit de echte config raken: alles via de nep-HOME hieronder.
unset XDG_CONFIG_HOME XDG_CACHE_HOME XDG_RUNTIME_DIR WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
STUB="$T/stub"; mkdir -p "$STUB"

for side in A B; do
    mkdir -p "$T/$side/home/.local/bin" "$T/$side/home/.config/kingstra" "$T/$side/run" "$T/$side/home/Downloads"
    ln -s "$REPO/config/shared/scripts/kingstra-koppel" "$T/$side/home/.local/bin/kingstra-koppel"
    printf '{"host":"peer","ip":"127.0.0.1","user":"%s","kant":"links","label":"laptop"}\n' "${USER:-joris}" \
        > "$T/$side/home/.config/kingstra/koppeling.json"
done

cat > "$STUB/ssh" <<'S'
#!/usr/bin/env bash
# alles wat geen optie is: eerst het doel, daarna de opdracht
args=(); while [[ $# -gt 0 ]]; do case "$1" in -o) shift 2 ;; -*) shift ;; *) args+=("$1"); shift ;; esac; done
echo "ssh ${args[*]:1}" >> "$KOPPEL_LOG"
peer="$( [[ "$HOME" == "$T/A/home" ]] && echo B || echo A )"
HOME="$T/$peer/home" XDG_RUNTIME_DIR="$T/$peer/run" bash -c "cd ~; ${args[*]:1}"
S
cat > "$STUB/scp" <<'S'
#!/usr/bin/env bash
args=(); while [[ $# -gt 0 ]]; do case "$1" in -o) shift 2 ;; --|-*) shift ;; *) args+=("$1"); shift ;; esac; done
dest="${args[-1]#*:}"; unset 'args[-1]'
peer="$( [[ "$HOME" == "$T/A/home" ]] && echo B || echo A )"
cp -r "${args[@]}" "${dest/#$T\/$peer\/home/$T/$peer/home}"
S
cat > "$STUB/wl-paste" <<'S'
#!/usr/bin/env bash
if [[ "$1" == --list-types ]]; then
    if [[ -f "$HOME/clip.type" ]]; then cat "$HOME/clip.type"; else printf 'text/plain;charset=utf-8\nUTF8_STRING\n'; fi
else
    cat "$HOME/clip"
fi
S
cat > "$STUB/wl-copy" <<'S'
#!/usr/bin/env bash
t=""; [[ "${1:-}" == -t ]] && t="$2"
cat > "$HOME/clip"
if [[ "$t" == x-special/* ]]; then printf '%s\n' "$t" > "$HOME/clip.type"; else rm -f "$HOME/clip.type"; fi
S
printf '#!/bin/sh\nexit 0\n' > "$STUB/notify-send"
printf '#!/bin/sh\nexit 0\n' > "$STUB/systemctl"
printf '#!/bin/sh\necho "$HOME/Downloads"\n' > "$STUB/xdg-user-dir"
chmod +x "$STUB"/*
export PATH="$STUB:$PATH" T KOPPEL_LOG="$T/log"; : > "$T/log"

side() { HOME="$T/$1/home" XDG_RUNTIME_DIR="$T/$1/run" "$T/$1/home/.local/bin/kingstra-koppel" "${@:2}"; }

echo "hallo van A" > "$T/A/home/clip"
side A _klembord-stuur </dev/null
for i in 1 2 3 4 5 6 7 8 9 10; do [[ -f "$T/B/home/clip" ]] && break; sleep 0.2; done
[[ "$(cat "$T/B/home/clip" 2>/dev/null)" == "hallo van A" ]] || { echo "FOUT: B kreeg het klembord niet"; exit 1; }

# B's watcher vuurt nu op dezelfde inhoud: mag niet terug naar A
n="$(wc -l < "$T/log")"
side B _klembord-stuur </dev/null
[[ "$(wc -l < "$T/log")" == "$n" ]] || { echo "FOUT: echo-lus, B stuurde terug"; exit 1; }

# A nog een keer hetzelfde: ook niets sturen
side A _klembord-stuur </dev/null
[[ "$(wc -l < "$T/log")" == "$n" ]] || { echo "FOUT: A stuurde dubbel"; exit 1; }

# Nieuwe inhoud op B gaat wel naar A
echo "terug van B" > "$T/B/home/clip"
side B _klembord-stuur </dev/null
sleep 0.5
[[ "$(cat "$T/A/home/clip")" == "terug van B" ]] || { echo "FOUT: A kreeg B's klembord niet"; exit 1; }

# Gekopieerde bestanden (Nautilus): de bestanden zelf komen op B klaar om te plakken
mkdir -p "$T/A/home/map met spatie/sub"
echo een > "$T/A/home/map met spatie/sub/a.txt"; echo twee > "$T/A/home/b é.txt"
printf 'copy\nfile://%s\nfile://%s' "${T// /%20}/A/home/map%20met%20spatie" "${T// /%20}/A/home/b%20%C3%A9.txt" > "$T/A/home/clip"
printf 'x-special/gnome-copied-files\ntext/uri-list\ntext/plain;charset=utf-8\n' > "$T/A/home/clip.type"
rm -f "$T/B/home/clip"
side A _klembord-stuur </dev/null
for i in 1 2 3 4 5 6 7 8 9 10; do [[ -f "$T/B/home/clip" ]] && break; sleep 0.2; done
km="$T/B/home/.cache/kingstra/klembord"
[[ "$(cat "$km/map met spatie/sub/a.txt" 2>/dev/null)" == een && -f "$km/b é.txt" ]] \
    || { echo "FOUT: gekopieerde bestanden niet aangekomen"; ls -R "$T/B/home/.cache" 2>&1; exit 1; }
grep -qx 'x-special/gnome-copied-files' "$T/B/home/clip.type" || { echo "FOUT: B kreeg geen bestanden op het klembord"; exit 1; }
[[ "$(head -n1 "$T/B/home/clip")" == copy ]] && grep -q "file://.*/klembord/b%20%C3%A9.txt" "$T/B/home/clip" \
    || { echo "FOUT: klembord op B klopt niet:"; cat "$T/B/home/clip"; exit 1; }
# B's watcher ziet zijn eigen klembordmap: niet terugsturen
n="$(wc -l < "$T/log")"
side B _klembord-stuur </dev/null
[[ "$(wc -l < "$T/log")" == "$n" ]] || { echo "FOUT: B stuurde ontvangen bestanden terug"; exit 1; }
rm -f "$T/A/home/clip.type" "$T/B/home/clip.type"

# Bestand sturen
echo inhoud > "$T/A/home/test bestand.txt"
side A stuur "$T/A/home/test bestand.txt" >/dev/null
[[ -f "$T/B/home/Downloads/test bestand.txt" ]] || { echo "FOUT: bestand kwam niet aan"; cat "$T/log"; exit 1; }

# Kant wisselen (Beeldschermen / kingstra koppel kant): beide kanten volgen
for side in A B; do
    mkdir -p "$T/$side/home/.config/lan-mouse"
    printf 'port = 4242\n\n[[clients]]\nposition = "left"\nhostname = "peer"\n' > "$T/$side/home/.config/lan-mouse/config.toml"
done
side A kant rechts >/dev/null
grep -q '^position = "right"' "$T/A/home/.config/lan-mouse/config.toml" || { echo "FOUT: A niet naar rechts"; exit 1; }
grep -q '^position = "left"' "$T/B/home/.config/lan-mouse/config.toml" || { echo "FOUT: B niet links"; exit 1; }
grep -q '"kant": "links"' "$T/B/home/.config/kingstra/koppeling.json" || { echo "FOUT: B-state niet links"; exit 1; }
grep -q '"kant": "rechts"' "$T/A/home/.config/kingstra/koppeling.json" || { echo "FOUT: A-state niet rechts"; exit 1; }

# Venster ook daar openen: zelfde app via het .desktop-bestand, bestand gaat mee
mkdir -p "$T/A/home/.local/share/applications" "$T/B/home/.local/share/applications"
printf '[Desktop Entry]\nName=Test\nExec=testapp %%F\nType=Application\n' > "$T/A/home/.local/share/applications/org.voorbeeld.testapp.desktop"
cp "$T/A/home/.local/share/applications/org.voorbeeld.testapp.desktop" "$T/B/home/.local/share/applications/"
echo doc > "$T/A/home/notities.txt"
bash -c 'sleep 30; :' _ "$T/A/home/notities.txt" & spid=$!
printf '#!/bin/sh\necho "{\\"class\\": \\"testapp\\", \\"pid\\": %s}"\n' "$spid" > "$STUB/hyprctl"
printf '#!/bin/sh\necho "$@" >> "$KOPPEL_LOG.start"\n' > "$STUB/systemd-run"
chmod +x "$STUB/hyprctl" "$STUB/systemd-run"
side A open >/dev/null
kill "$spid" 2>/dev/null || true
grep -q "gio launch $T/B/home/.local/share/applications/org.voorbeeld.testapp.desktop $T/B/home/Downloads/notities.txt" "$KOPPEL_LOG.start" \
    || { echo "FOUT: open startte niet goed:"; cat "$KOPPEL_LOG.start" 2>/dev/null; exit 1; }
[[ -f "$T/B/home/Downloads/notities.txt" ]] || { echo "FOUT: bestand ging niet mee"; exit 1; }

# IP verversen: B antwoordt vanaf een ander bronadres (twee DHCP-clients).
# Stub-ip: "route get" geeft als src het adres uit ~/bron-ip van die kant.
cat > "$STUB/ip" <<'S'
#!/usr/bin/env bash
[[ "$*" == "-4 route get "* ]] || exit 1
echo "${4} dev wlan0 src $(cat "$HOME/bron-ip") uid 1000"
S
chmod +x "$STUB/ip"
echo 192.168.1.64 > "$T/A/home/bron-ip"; echo 192.168.1.25 > "$T/B/home/bron-ip"
printf '{"host":"peer","ip":"192.168.1.26","user":"%s","kant":"links","label":"laptop"}\n' "${USER:-joris}" \
    > "$T/A/home/.config/kingstra/koppeling.json"
printf 'port = 4242\n\n[[clients]]\nposition = "left"\nhostname = "peer"\nips = ["192.168.1.26"]\nactivate_on_startup = true\n' \
    > "$T/A/home/.config/lan-mouse/config.toml"
lm_ip() { sed -n 's/^ips = \["\(.*\)"\]/\1/p' "$T/A/home/.config/lan-mouse/config.toml"; }
st_ip() { python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["ip"])' "$T/A/home/.config/kingstra/koppeling.json"; }

# ssh lukt niet: opgeslagen IP blijft staan
printf '#!/bin/sh\nexit 255\n' > "$T/ssh-fout"; chmod +x "$T/ssh-fout"
cp "$STUB/ssh" "$T/ssh-goed"; cp "$T/ssh-fout" "$STUB/ssh"
side A _ververs-ip 2>/dev/null && { echo "FOUT: ververs-ip meldde wijziging zonder ssh"; exit 1; }
[[ "$(st_ip)" == 192.168.1.26 && "$(lm_ip)" == 192.168.1.26 ]] || { echo "FOUT: IP veranderd terwijl ssh faalde"; exit 1; }
cp "$T/ssh-goed" "$STUB/ssh"

# --als-nodig zonder mislukte handshake: geen ssh, niets veranderd
printf '#!/bin/sh\nexit 0\n' > "$STUB/journalctl"; chmod +x "$STUB/journalctl"
n="$(wc -l < "$T/log")"
side A _ververs-ip --als-nodig 2>/dev/null && { echo "FOUT: --als-nodig deed iets zonder fout"; exit 1; }
[[ "$(wc -l < "$T/log")" == "$n" && "$(st_ip)" == 192.168.1.26 ]] || { echo "FOUT: --als-nodig gebruikte ssh zonder reden"; exit 1; }

# Bij het starten (ExecStartPre): het bronadres van B wordt overgenomen
side A _ververs-ip 2>/dev/null || { echo "FOUT: ververs-ip zag het nieuwe adres niet"; cat "$T/log"; exit 1; }
[[ "$(st_ip)" == 192.168.1.25 ]] || { echo "FOUT: koppeling.json niet bijgewerkt ($(st_ip))"; exit 1; }
[[ "$(lm_ip)" == 192.168.1.25 ]] || { echo "FOUT: lan-mouse config niet bijgewerkt ($(lm_ip))"; exit 1; }
grep -q '^hostname = "peer"' "$T/A/home/.config/lan-mouse/config.toml" || { echo "FOUT: lan-mouse config beschadigd"; exit 1; }
# Zelfde adres: niets te doen
side A _ververs-ip 2>/dev/null && { echo "FOUT: ververs-ip meldde wijziging bij gelijk adres"; exit 1; }

# Timer: handshake mislukt en B wisselt weer → bijwerken én lan-mouse herstarten
printf '#!/bin/sh\necho "lan-mouse: failed to connect to 192.168.1.25:4242"\n' > "$STUB/journalctl"
printf '#!/bin/sh\necho "$@" >> "$KOPPEL_LOG.systemctl"\nexit 0\n' > "$STUB/systemctl"
echo 192.168.1.26 > "$T/B/home/bron-ip"
side A _ververs-ip --als-nodig 2>/dev/null || { echo "FOUT: --als-nodig werkte niet bij mislukte handshake"; exit 1; }
[[ "$(st_ip)" == 192.168.1.26 && "$(lm_ip)" == 192.168.1.26 ]] || { echo "FOUT: --als-nodig zette IP niet"; exit 1; }
grep -q 'restart kingstra-lan-mouse.service' "$KOPPEL_LOG.systemctl" || { echo "FOUT: lan-mouse niet herstart"; exit 1; }

echo "koppel: ok"
