#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

has_cmd() { command -v "$1" >/dev/null 2>&1; }
ensure_dir() { mkdir -p -- "$1"; }
log_ok() { :; }
log_dry() { :; }
log_error() { printf 'ERROR: %s\n' "$*" >&2; }

# shellcheck source=/dev/null
source "$REPO_ROOT/installer/lib/validate.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/installer/phases/14_profiles.sh"

test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT

DRY_RUN=false
TOUCHPAD_NATURAL_SCROLL=true

run_case() {
    local gpu="$1"
    local laptop="$2"
    local touchpad="$3"
    local tablet="$4"
    local output="$test_dir/hardware-${gpu}-${laptop}-${touchpad}-${tablet}.lua"

    DETECT_GPU="$gpu"
    DETECT_IS_LAPTOP="$laptop"
    DETECT_HAS_TOUCHPAD="$touchpad"
    DETECT_HAS_TOUCHSCREEN="$tablet"
    ENABLE_TABLET_MODE="$tablet"

    _phase14_write_hardware_lua "$output"
    lua_file_syntax_check "$output"
}

run_case nvidia true true true
run_case amd true true false
run_case intel false false false
run_case unknown false false false

# Een ongeldige generatie mag de laatst geldige actieve config niet vervangen.
protected_output="$test_dir/protected-hardware.lua"
DETECT_GPU=intel
DETECT_IS_LAPTOP=true
DETECT_HAS_TOUCHPAD=true
DETECT_HAS_TOUCHSCREEN=false
ENABLE_TABLET_MODE=false
TOUCHPAD_NATURAL_SCROLL=true
_phase14_write_hardware_lua "$protected_output"
cp -- "$protected_output" "$protected_output.before"

TOUCHPAD_NATURAL_SCROLL='invalid Lua !'
if _phase14_write_hardware_lua "$protected_output" 2>/dev/null; then
    printf 'generator accepteerde opzettelijk ongeldige Lua\n' >&2
    exit 1
fi
cmp --silent "$protected_output.before" "$protected_output"

printf 'hardware.lua generator smoke test: OK\n'
