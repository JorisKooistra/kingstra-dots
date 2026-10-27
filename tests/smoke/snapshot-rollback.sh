#!/usr/bin/env bash
# shellcheck disable=SC2034 # variabelen worden gelezen door gesourcete code
# Terugzetpunt maken, rollback, vastzetten en loslaten, plus eenmalige migraties.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

export HOME="$TEST_ROOT/home"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_DATA_HOME="$HOME/.local/share"
mkdir -p "$HOME"

FAKE_REPO="$TEST_ROOT/repo"
git init -q -b main "$FAKE_REPO"
git -C "$FAKE_REPO" config user.email t@example.com
git -C "$FAKE_REPO" config user.name test
cat > "$FAKE_REPO/install.sh" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$HOME/installer-ran"
SH
echo een > "$FAKE_REPO/stand"
git -C "$FAKE_REPO" add -A && git -C "$FAKE_REPO" commit -q -m een
export KINGSTRA_REPO="$FAKE_REPO"

fail() { echo "FOUT: $*" >&2; exit 1; }

# 1. Terugzetpunt maken
out="$(bash "$REPO_ROOT/config/shared/scripts/kingstra-snapshot" create "test")"
grep -q "Dotfiles: terugzetpunt kingstra/pre-update-" <<< "$out" || fail "geen tag-melding: $out"
tag="$(git -C "$FAKE_REPO" tag --list 'kingstra/pre-update-*' | head -n 1)"
[[ -n "$tag" ]] || fail "geen pre-update-tag"
grep -q "|$tag|" "$XDG_STATE_HOME/kingstra/snapshots.log" || fail "niet gelogd"
bash "$REPO_ROOT/config/shared/scripts/kingstra-snapshot" list | grep -q "$tag" || fail "list toont tag niet"

# 2. Nieuwe "update", dan terug
echo twee > "$FAKE_REPO/stand"
git -C "$FAKE_REPO" commit -q -am twee
bash "$REPO_ROOT/config/shared/scripts/kingstra-rollback" --dry-run | grep -q "Dry-run" || fail "dry-run"
[[ "$(cat "$FAKE_REPO/stand")" == "twee" ]] || fail "dry-run wijzigde iets"
bash "$REPO_ROOT/config/shared/scripts/kingstra-rollback" >/dev/null
[[ "$(cat "$FAKE_REPO/stand")" == "een" ]] || fail "rollback zette de stand niet terug"
[[ "$(cat "$HOME/installer-ran")" == "--yes" ]] || fail "installer niet gedraaid"
[[ -f "$XDG_STATE_HOME/kingstra/update-hold" ]] || fail "geen update-hold"
git -C "$FAKE_REPO" tag --list 'kingstra/pre-rollback-*' | grep -q . || fail "geen pre-rollback-tag"

# 3. Vuile repo blokkeert de rollback
echo lokaal > "$FAKE_REPO/stand"
if bash "$REPO_ROOT/config/shared/scripts/kingstra-rollback" >/dev/null 2>&1; then
    fail "rollback negeerde lokale wijzigingen"
fi
git -C "$FAKE_REPO" checkout -q -- stand

# 4. Loslaten
bash "$REPO_ROOT/config/shared/scripts/kingstra-rollback" --release >/dev/null
[[ ! -f "$XDG_STATE_HOME/kingstra/update-hold" ]] || fail "release liet hold staan"

# 5. Migraties draaien één keer, een verse installatie markeert alleen
log_step() { :; }; log_ok() { :; }; log_warn() { :; }; log_dry() { :; }
REPO_ROOT_SAVED="$REPO_ROOT"
REPO_ROOT="$TEST_ROOT/mig"
mkdir -p "$REPO_ROOT/installer/migrations"
cat > "$REPO_ROOT/installer/migrations/0001-teller.sh" <<'SH'
migration_run() { echo x >> "$HOME/teller"; }
SH
cat > "$REPO_ROOT/installer/migrations/0002-faalt.sh" <<'SH'
migration_run() { return 1; }
SH
# shellcheck source=/dev/null
source "$REPO_ROOT_SAVED/installer/lib/migrations.sh"
INSTALL_WAS_PRESENT=true
run_pending_migrations || true
run_pending_migrations || true
[[ "$(wc -l < "$HOME/teller")" -eq 1 ]] || fail "migratie draaide niet precies één keer"
grep -qx "0002-faalt" "$MIGRATIONS_STATE" && fail "mislukte migratie gemarkeerd"
rm -f "$MIGRATIONS_STATE" "$HOME/teller"
INSTALL_WAS_PRESENT=false
run_pending_migrations || true
[[ ! -f "$HOME/teller" ]] || fail "verse installatie draaide een migratie"
grep -qx "0001-teller" "$MIGRATIONS_STATE" || fail "verse installatie markeerde niet"

echo "Snapshot/rollback/migraties smoke test: OK"
