#!/usr/bin/env bash
# Runs the automated checks used by CI: smoke tests, shellcheck and qmllint.
# Usage: tests/scripts/check.sh [smoke|shellcheck|shellcheck-warnings|qmllint]...
# Without arguments it runs smoke, shellcheck and qmllint.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

QMLLINT="${QMLLINT:-$(command -v qmllint || command -v qmllint6 || echo /usr/lib/qt6/bin/qmllint)}"

run_smoke() {
    local test failed=0
    for test in tests/smoke/*.sh; do
        printf '==> %s\n' "$test"
        bash "$test" || failed=1
    done
    return "$failed"
}

# All tracked *.sh files plus extensionless scripts with a sh/bash shebang.
shell_files() {
    git ls-files -z | while IFS= read -r -d '' f; do
        [[ -f "$f" ]] || continue
        if [[ "$f" == *.sh ]] || head -n1 -- "$f" 2>/dev/null | grep -qE '^#!.*\b(ba)?sh\b'; then
            printf '%s\0' "$f"
        fi
    done
}

# Only errors fail the build; `shellcheck-warnings` prints the wider report.
run_shellcheck() {
    local severity="$1"
    local -a files
    mapfile -d '' files < <(shell_files)
    printf 'shellcheck (%s): %d files\n' "$severity" "${#files[@]}"
    shellcheck --severity="$severity" --format=gcc "${files[@]}"
}

# Quickshell's QML modules are not available on CI, so type/import checks would only
# produce noise. Every semantic category is disabled: this is a syntax check.
run_qmllint() {
    local -a files flags=()
    local category
    for category in alias compiler controls-sanity deferred-property-id deprecated import \
        inheritance-cycle multiline-strings multiple-attached-objects plugin property \
        required signal type unqualified unused-imports with; do
        flags+=("--$category" disable)
    done
    mapfile -t files < <(git ls-files '*.qml')
    printf 'qmllint: %d files\n' "${#files[@]}"
    "$QMLLINT" --ignore-settings "${flags[@]}" "${files[@]}"
}

checks=("$@")
[[ ${#checks[@]} -gt 0 ]] || checks=(smoke shellcheck qmllint)

status=0
for check in "${checks[@]}"; do
    case "$check" in
        smoke) run_smoke || status=1 ;;
        shellcheck) run_shellcheck error || status=1 ;;
        shellcheck-warnings) run_shellcheck warning || status=1 ;;
        qmllint) run_qmllint || status=1 ;;
        *) printf 'Onbekende check: %s\n' "$check" >&2; exit 2 ;;
    esac
done
exit "$status"
