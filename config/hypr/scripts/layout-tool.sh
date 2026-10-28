#!/usr/bin/env bash
# Stable entry point used by the shell, launcher and keyboard shortcuts.
set -euo pipefail
exec python3 "$(dirname "${BASH_SOURCE[0]}")/workspace-layout.py" "$@"
