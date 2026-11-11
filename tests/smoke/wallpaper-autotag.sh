#!/usr/bin/env bash
# Zie wallpaper-autotag.py: eigen foto's krijgen automatisch tags.
set -euo pipefail
unset XDG_CONFIG_HOME
exec python3 "$(dirname "$0")/wallpaper-autotag.py"
