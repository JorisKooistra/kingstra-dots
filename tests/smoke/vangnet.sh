#!/usr/bin/env bash
# Smoke test voor het vangnet: opstartmenu met teller, back-up (met een
# nep-restic), transactie uit pacman.log en terugdraaien, gezondheidscheck.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fail() { echo "FOUT: $*" >&2; exit 1; }

# --- Opstartmenu ---------------------------------------------------------------
ESP="$T/esp"
mkdir -p "$ESP/loader/entries"
touch "$ESP/vmlinuz-linux" "$ESP/vmlinuz-linux-lts"
cat > "$ESP/loader/entries/arch_linux.conf" <<'EOF'
title Arch Linux (linux)
linux /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux.img
options root=PARTUUID=abc rw rootfstype=ext4 quiet
EOF
sed 's/(linux)/(linux-lts)/; s/vmlinuz-linux/vmlinuz-linux-lts/; s/initramfs-linux/initramfs-linux-lts/' \
    "$ESP/loader/entries/arch_linux.conf" > "$ESP/loader/entries/arch_linux-lts.conf"
sed 's/initramfs-linux.img/initramfs-linux-fallback.img/' \
    "$ESP/loader/entries/arch_linux.conf" > "$ESP/loader/entries/arch_linux-fallback.conf"
printf 'default arch_linux.conf\ntimeout 3\n' > "$ESP/loader/loader.conf"

boot() {
    python3 - "$REPO_ROOT/config/system/vangnet/kingstra-boot-entries" "$@" <<'PY'
import os, sys
path, *args = sys.argv[1:]
src = open(path).read().replace("os.geteuid() != 0", "False")
sys.argv = [path, *args]
code = compile(src, path, "exec")
try:
    exec(code, {"__name__": "__main__"})
except SystemExit as exc:
    if exc.code not in (0, None):
        raise
PY
}
export KINGSTRA_ESP="$ESP" KINGSTRA_BOOT_BACKUPS="$T/boot-backups"
boot setup >/dev/null
[[ -f "$ESP/loader/entries/kingstra-linux+3.conf" ]] || fail "kingstra-linux+3.conf ontbreekt"
[[ -f "$ESP/loader/entries/kingstra-linux-lts+3.conf" ]] || fail "lts-item ontbreekt"
[[ -f "$ESP/loader/entries/kingstra-herstel.conf" ]] || fail "herstel-item ontbreekt"
grep -q '^default kingstra-\*$' "$ESP/loader/loader.conf" || fail "default niet gezet"
grep -q '^timeout 0$' "$ESP/loader/loader.conf" || fail "timeout niet gezet"
grep -q 'root=PARTUUID=abc rw rootfstype=ext4 quiet splash' "$ESP/loader/entries/kingstra-linux+3.conf" \
    || fail "opties niet overgenomen of quiet dubbel"
grep -q 'initramfs-linux-lts.img' "$ESP/loader/entries/kingstra-herstel.conf" || fail "herstel hoort de lts-kernel te gebruiken"
grep -q 'systemd.unit=multi-user.target' "$ESP/loader/entries/kingstra-herstel.conf" || fail "herstel start niet zonder inlogscherm"
[[ -f "$ESP/loader/entries/arch_linux.conf" ]] || fail "bestaand item verdwenen"
# Goedgekeurd door systemd-bless-boot, daarna een nieuwe kernel: weer 3 pogingen.
mv "$ESP/loader/entries/kingstra-linux+3.conf" "$ESP/loader/entries/kingstra-linux.conf"
boot setup >/dev/null
[[ -f "$ESP/loader/entries/kingstra-linux.conf" ]] || fail "setup mag een goedgekeurd item niet opnieuw tellen"
boot arm linux >/dev/null
[[ -f "$ESP/loader/entries/kingstra-linux+3.conf" && ! -f "$ESP/loader/entries/kingstra-linux.conf" ]] \
    || fail "arm zet geen teller"
mv "$ESP/loader/entries/kingstra-linux+3.conf" "$ESP/loader/entries/kingstra-linux+0-3.conf"
boot status | grep -q 'MISLUKT' || fail "status meldt mislukte kernel niet"

# --- Back-up met een nep-restic ---------------------------------------------------
mkdir -p "$T/bin" "$T/home/.config/kingstra"
cat > "$T/bin/restic" <<'EOF'
#!/bin/bash
for a in "$@"; do
  case $a in
    init) mkdir -p "$FAKE_REPO"; touch "$FAKE_REPO/config" ;;
    backup) echo '{"message_type":"summary","data_added":2048,"files_new":3,"files_changed":1}' ;;
    snapshots) echo '[{"id":"a"},{"id":"b"}]' ;;
  esac
done
EOF
printf '#!/bin/bash\necho /mnt/nep\n' > "$T/bin/findmnt"
chmod +x "$T/bin/restic" "$T/bin/findmnt"
echo "BACKUP_REPO=$T/repo" > "$T/home/.config/kingstra/backup.conf"
PATH="$T/bin:$PATH" HOME="$T/home" XDG_CACHE_HOME="$T/home/.cache" XDG_CONFIG_HOME="$T/home/.config" \
    FAKE_REPO="$T/repo" bash "$REPO_ROOT/config/shared/scripts/kingstra-backup" run >/dev/null
python3 - "$T/home/.cache/kingstra/backup-status.json" <<'PY' || fail "back-upstatus klopt niet"
import json, sys
d = json.load(open(sys.argv[1]))
assert d["snapshots"] == 2 and d["changed_files"] == 4 and d["last_ok"] > 0 and not d["running"], d
PY
grep -qx "$T/home/.cache" "$T/home/.cache/kingstra/backup-exclude.effective" || fail "cache niet uitgesloten"
# Doelschijf niet gekoppeld (findmnt geeft /): nooit naar de systeemschijf schrijven.
printf '#!/bin/bash\necho /\n' > "$T/bin/findmnt"
if PATH="$T/bin:$PATH" HOME="$T/home" XDG_CACHE_HOME="$T/home/.cache" XDG_CONFIG_HOME="$T/home/.config" \
    FAKE_REPO="$T/repo" bash "$REPO_ROOT/config/shared/scripts/kingstra-backup" run >/dev/null 2>&1; then
    fail "back-up liep door zonder gekoppelde schijf"
fi

# --- Transactie uit pacman.log en terugdraaien -----------------------------------
cat > "$T/pacman.log" <<'EOF'
[2026-11-02T09:00:01+0100] [ALPM] upgraded oud (1.0-1 -> 1.1-1)
[2026-11-02T09:31:06+0100] [ALPM] upgraded linux (7.2.11.arch1-1 -> 7.2.14.arch1-1)
[2026-11-02T09:31:07+0100] [ALPM] installed nieuw (2.0-1)
EOF
lines="$(sed -n '/^record_transaction() {/,/^}/p' "$REPO_ROOT/config/quickshell/package_upgrade.sh")"
(
    PACMAN_LOG="$T/pacman.log" STATE_DIR="$T/state/kingstra/updates" LOG_FILE=""
    to_log() { :; }
    eval "$lines"
    record_transaction "2026-11-02T09:30:00"
    [[ "$TX_UPGRADED" == 1 && "$TX_INSTALLED" == 1 ]] || fail "transactie telt verkeerd: $TX_UPGRADED/$TX_INSTALLED"
    grep -q $'^upgraded\tlinux\t7.2.11.arch1-1\t7.2.14.arch1-1$' "$TX_FILE" || fail "transactieregel klopt niet"
)
mkdir -p "$T/cache"
touch "$T/cache/linux-7.2.11.arch1-1-x86_64.pkg.tar.zst" "$T/cache/linux-headers-7.2.11.arch1-1-x86_64.pkg.tar.zst"
out="$(XDG_STATE_HOME="$T/state" KINGSTRA_PKG_CACHE="$T/cache" KINGSTRA_REPO="$REPO_ROOT" \
    bash "$REPO_ROOT/config/shared/scripts/kingstra-rollback" --system --dry-run)"
grep -q 'linux-7.2.11.arch1-1-x86_64' <<< "$out" || fail "oude kernel niet gevonden in de cache"
grep -q 'linux-headers' <<< "$out" && fail "linux-headers ten onrechte meegenomen"

# --- Gezondheidscheck --------------------------------------------------------------
json="$(HOME="$T/home" XDG_CACHE_HOME="$T/home/.cache" bash "$REPO_ROOT/config/shared/scripts/kingstra-health" --json || true)"
python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert any(r["key"]=="backup" for r in d), d' "$json" \
    || fail "gezondheidscheck ziet de back-up niet"

echo "Vangnet smoke test: OK"
