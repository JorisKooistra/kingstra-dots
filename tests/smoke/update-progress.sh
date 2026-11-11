#!/usr/bin/env bash
# De voortgangsregel van de updater: herkent pacman-fases, de kernel-stap en
# AUR-builds uit de ruwe uitvoer.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
UPDATER="$REPO_ROOT/config/quickshell/package_upgrade.sh"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
fail() { echo "FOUT: $*" >&2; exit 1; }

eval "$(sed -n '/^PROG_LABEL=/,/^}/p' "$UPDATER")"
AUR_COUNT=2
out="$TMP/out"

expect() { # <verwacht label-begin> <regels...>
    local want="$1"; shift
    printf '%s\n' "$@" > "$out"
    PROG_KERNEL=false
    describe_output "$out" "pacman"
    [[ "$PROG_LABEL" == "$want"* ]] || fail "verwacht '$want', kreeg '$PROG_LABEL'"
}

expect "Downloaden" ":: Retrieving packages..." " linux-7.2 downloading..."
expect "Installeren: mesa" ":: Processing package changes..." "(1/3) upgrading linux" "(2/3) upgrading mesa"
[[ "$PROG_DONE/$PROG_TOTAL" == "2/3" ]] || fail "teller: $PROG_DONE/$PROG_TOTAL"
expect "Kernel: oude opstartbestanden weghalen" ":: Running pre-transaction hooks..." "(1/2) Removing linux initcpios..."
$PROG_KERNEL || fail "kernel-stap niet herkend"
expect "Kernel: nieuwe opstartbestanden bouwen · hook systemd" ":: Running post-transaction hooks..." \
    "(2/4) Updating linux initcpios..." "==> Building image from preset: /etc/mkinitcpio.d/linux.preset: 'default'" \
    "  -> Running build hook: [systemd]"
expect "Afronden: Updating icon" ":: Running post-transaction hooks..." "(2/4) Updating linux initcpios..." \
    "==> Image generation successful" "(3/4) Updating icon theme caches..."
expect "AUR bouwen: foo-bin" ":: Searching AUR for updates..." "==> Making package: foo-bin 2-1 (x)" "  -> Extracting sources..."
[[ "$PROG_DONE/$PROG_TOTAL" == "1/2" ]] || fail "AUR-teller: $PROG_DONE/$PROG_TOTAL"
# Echte pacman zonder terminal (log 10-11): geen tellers bij controles en installeren.
REPO_COUNT=4
expect "Sleutels controleren" ":: Proceed with installation? [Y/n] " "checking keyring..."
expect "Bestandsconflicten zoeken" "checking keyring..." "checking for file conflicts..."
expect "Installeren: claude-desktop" ":: Processing package changes..." "upgrading shelly-bin..." "upgrading claude-desktop..."
[[ "$PROG_DONE/$PROG_TOTAL" == "2/4" ]] || fail "teller zonder pacman-nummers: $PROG_DONE/$PROG_TOTAL"
expect "Afronden: etckeeper" ":: Running post-transaction hooks..." "(5/5) etckeeper: post-transaction commit"
# Een gewone pakketupdate van mkinitcpio is geen kernel-stap.
expect "Installeren: mkinitcpio" ":: Processing package changes..." "(1/1) upgrading mkinitcpio"
$PROG_KERNEL && fail "mkinitcpio-pakket ten onrechte als kernel-stap gezien"

echo "Update progress smoke test: OK"
