#!/usr/bin/env bash
# Zie battery-watch.py: batterijwaarschuwingen met nep-sysfs.
set -euo pipefail
unset XDG_CONFIG_HOME
exec python3 "$(dirname "$0")/battery-watch.py"
