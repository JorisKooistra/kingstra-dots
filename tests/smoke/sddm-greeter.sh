#!/usr/bin/env bash
set -euo pipefail
python3 tests/smoke/sddm-greeter.py
python3 tests/smoke/sddm-sync.py
