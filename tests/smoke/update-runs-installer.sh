#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
UPDATER="$REPO_ROOT/config/quickshell/package_upgrade.sh"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

TEST_HOME="$TEST_ROOT/home"
FAKE_REPO="$TEST_ROOT/kingstra-dots"
FAKE_BIN="$TEST_ROOT/bin"
INSTALL_MARKER="$TEST_ROOT/installer-ran"

mkdir -p \
    "$TEST_HOME/.local/share/kingstra" \
    "$TEST_HOME/.config/quickshell" \
    "$FAKE_REPO/.git" \
    "$FAKE_BIN"

printf 'Repo:        %s\n' "$FAKE_REPO" > "$TEST_HOME/.local/share/kingstra/install-complete"

cat > "$FAKE_BIN/git" <<'EOF'
#!/usr/bin/env bash
case " $* " in
    *" symbolic-ref "*) printf '%s\n' main ;;
    *" fetch "*) exit 0 ;;
    *" rev-parse --abbrev-ref "*) printf '%s\n' origin/main ;;
    *" rev-list --count HEAD..origin/main "*) printf '%s\n' 1 ;;
    *" rev-list --count origin/main..HEAD "*) printf '%s\n' 0 ;;
    *" status --porcelain "*) exit 0 ;;
    *" merge --ff-only origin/main "*) exit 0 ;;
    *) exit 0 ;;
esac
EOF

cat > "$FAKE_BIN/yay" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat > "$FAKE_BIN/flatpak" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat > "$FAKE_REPO/install.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ " $* " == *" --yes "* ]]
printf '%s\n' "$*" > "$TEST_INSTALL_MARKER"
EOF

cat > "$TEST_HOME/.config/quickshell/package_updates.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

chmod +x \
    "$FAKE_BIN/git" \
    "$FAKE_BIN/yay" \
    "$FAKE_BIN/flatpak" \
    "$FAKE_REPO/install.sh" \
    "$TEST_HOME/.config/quickshell/package_updates.sh"

HOME="$TEST_HOME" \
XDG_DATA_HOME="$TEST_HOME/.local/share" \
XDG_CACHE_HOME="$TEST_HOME/.cache" \
TEST_INSTALL_MARKER="$INSTALL_MARKER" \
PATH="$FAKE_BIN:/usr/bin" \
    bash "$UPDATER" </dev/null >/dev/null

[[ -s "$INSTALL_MARKER" ]]
grep -q -- '--yes' "$INSTALL_MARKER"

printf 'Update runner installer hand-off smoke test: OK\n'
