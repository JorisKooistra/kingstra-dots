#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AUDIT="$REPO_ROOT/config/quickshell/package_audit.sh"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

FAKE_BIN="$TEST_ROOT/bin"
TEST_HOME="$TEST_ROOT/home"
mkdir -p "$FAKE_BIN" "$TEST_HOME/.local/share/kingstra"
printf 'Repo:        %s\n' "$REPO_ROOT" > "$TEST_HOME/.local/share/kingstra/install-complete"

# hyprland komt uit het manifest, linux is basis, gimp en oude-tool zijn
# kandidaten; pacman -Rns mag nooit worden aangeroepen.
cat > "$FAKE_BIN/pacman" <<'EOS'
#!/usr/bin/env bash
case "$1" in
    -Qq) printf '%s\n' hyprland linux gimp oude-tool libfoo foo-git ;;
    -Qeq) printf '%s\n' hyprland linux gimp oude-tool foo-git ;;
    -Qetq) printf '%s\n' hyprland linux gimp oude-tool ;;
    -Qmq) printf '%s\n' foo-git ;;
    -Qdtq) printf '%s\n' libfoo ;;
    -Qgq) exit 1 ;;
    -Qlq) exit 0 ;;
    -Qi)
        shift
        for p in "$@"; do
            printf 'Name            : %s\nInstalled Size  : 120.50 MiB\nInstall Date    : Mon 05 Jan 2026 10:00:00 AM CET\n\n' "$p"
        done
        ;;
    *) echo "onverwacht: $*" >&2; exit 99 ;;
esac
EOS
printf '#!/usr/bin/env bash\necho "sudo mag niet" >&2; exit 98\n' > "$FAKE_BIN/sudo"
chmod +x "$FAKE_BIN/pacman" "$FAKE_BIN/sudo"

run() {
    HOME="$TEST_HOME" XDG_DATA_HOME="$TEST_HOME/.local/share" XDG_CONFIG_HOME="$TEST_HOME/.config" \
        PATH="$FAKE_BIN:/usr/bin:/bin" bash "$AUDIT" "$@"
}

out="$(run </dev/null)"
grep -q 'gimp' <<< "$out"
grep -q 'oude-tool' <<< "$out"
grep -q 'foo-git' <<< "$out"
! grep -qE '^  (hyprland|linux) ' <<< "$out"

summary="$(run --summary)"
grep -q '^2 kandidaten' <<< "$summary"

run --keep gimp >/dev/null
grep -qx gimp "$TEST_HOME/.config/kingstra/package-keep.txt"
grep -q '^1 kandidaten' <<< "$(run --summary)"

# Review zonder antwoorden verwijdert niets.
review="$(run --review </dev/null)"
grep -q 'Niets verwijderd' <<< "$review"

printf 'Package audit smoke test: OK\n'
