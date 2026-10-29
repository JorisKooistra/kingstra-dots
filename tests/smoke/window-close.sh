#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
lua tests/smoke/window-close.lua
