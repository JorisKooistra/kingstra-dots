#!/usr/bin/env bash
# Smoke-test kingstra-koppel: klembord heen en terug zonder echo-lus, en
# bestanden sturen. ssh/wl-paste/wl-copy/notify-send zijn stubs; de "andere
# machine" is een tweede HOME in een tijdelijke map.
set -euo pipefail
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
case "$1" in --list-types) printf 'text/plain;charset=utf-8\nUTF8_STRING\n' ;; *) cat "$HOME/clip" ;; esac
S
cat > "$STUB/wl-copy" <<'S'
#!/usr/bin/env bash
cat > "$HOME/clip"
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

echo "koppel: ok"
