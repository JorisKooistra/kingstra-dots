#!/usr/bin/env bash
# De updater zet eigen wijzigingen opzij, werkt bij en zet ze terug; botsen
# ze met de update, dan blijft alles op de oude stand.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
UPDATER="$REPO_ROOT/config/quickshell/package_upgrade.sh"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

fail() { echo "FOUT: $*" >&2; exit 1; }
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

setup() {
    rm -rf "$TEST_ROOT/case" && mkdir -p "$TEST_ROOT/case"
    CASE="$TEST_ROOT/case"
    TEST_HOME="$CASE/home"
    FAKE_BIN="$CASE/bin"
    ORIGIN="$CASE/origin.git"
    UPSTREAM="$CASE/upstream"
    LOCAL="$CASE/local"
    mkdir -p "$TEST_HOME/.local/share/kingstra" "$TEST_HOME/.config/quickshell" "$FAKE_BIN"

    git init -q --bare -b main "$ORIGIN"
    git clone -q "$ORIGIN" "$UPSTREAM" 2>/dev/null
    git -C "$UPSTREAM" config user.email t@example.com
    git -C "$UPSTREAM" config user.name test
    git -C "$UPSTREAM" checkout -q -b main
    printf 'a\n' > "$UPSTREAM/binds.lua"
    printf 'x\n' > "$UPSTREAM/other"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$UPSTREAM/install.sh"
    git -C "$UPSTREAM" add -A && git -C "$UPSTREAM" commit -q -m start
    git -C "$UPSTREAM" push -q origin main
    git clone -q "$ORIGIN" "$LOCAL"
    printf 'Repo:        %s\n' "$LOCAL" > "$TEST_HOME/.local/share/kingstra/install-complete"

    for tool in yay flatpak curl; do
        printf '#!/usr/bin/env bash\nexit 0\n' > "$FAKE_BIN/$tool"
        chmod +x "$FAKE_BIN/$tool"
    done
    printf '#!/usr/bin/env bash\nexit 0\n' > "$TEST_HOME/.config/quickshell/package_updates.sh"
    chmod +x "$TEST_HOME/.config/quickshell/package_updates.sh"
}

run_updater() {
    HOME="$TEST_HOME" XDG_DATA_HOME="$TEST_HOME/.local/share" \
    XDG_CACHE_HOME="$TEST_HOME/.cache" XDG_STATE_HOME="$TEST_HOME/.local/state" \
    KINGSTRA_SNAPSHOT_CMD=/nonexistent \
    GIT_CONFIG_GLOBAL=/dev/null \
    PATH="$FAKE_BIN:/usr/bin:/bin" \
        bash "$UPDATER" </dev/null >"$CASE/out" 2>&1 || true
}

# 1. Geen botsing: update en eigen wijziging allebei aanwezig.
setup
printf 'y\n' > "$UPSTREAM/other" && git -C "$UPSTREAM" commit -q -am upd && git -C "$UPSTREAM" push -q origin main
printf 'eigen\n' > "$LOCAL/binds.lua"
run_updater
[[ "$(cat "$LOCAL/other")" == "y" ]] || { cat "$CASE/out"; fail "update niet toegepast"; }
[[ "$(cat "$LOCAL/binds.lua")" == "eigen" ]] || fail "eigen wijziging kwijt"
[[ -z "$(git -C "$LOCAL" stash list)" ]] || fail "stash bleef staan"

# 2. Botsing: alles blijft op de oude stand, eigen wijziging intact.
setup
old="$(git -C "$LOCAL" rev-parse HEAD)"
printf 'b\n' > "$UPSTREAM/binds.lua" && git -C "$UPSTREAM" commit -q -am upd && git -C "$UPSTREAM" push -q origin main
printf 'eigen\n' > "$LOCAL/binds.lua"
run_updater
[[ "$(git -C "$LOCAL" rev-parse HEAD)" == "$old" ]] || fail "HEAD verschoof bij botsing"
[[ "$(cat "$LOCAL/binds.lua")" == "eigen" ]] || fail "eigen wijziging kwijt bij botsing"
[[ -z "$(git -C "$LOCAL" stash list)" ]] || fail "stash bleef staan bij botsing"
grep -q "botsen met de update" "$CASE/out" || fail "geen melding over botsing"

echo "Update autostash smoke test: OK"
