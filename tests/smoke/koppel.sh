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

echo "koppel: ok"
