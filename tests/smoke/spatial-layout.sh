#!/usr/bin/env bash
set -euo pipefail
spatial_runtime="$(mktemp -d)"
trap 'rm -rf "$spatial_runtime"' EXIT
export XDG_RUNTIME_DIR="$spatial_runtime"
lua tests/smoke/spatial-core.lua
lua tests/smoke/spatial-adapter.lua
python3 - <<'PY'
import json
import os
from pathlib import Path
data = json.loads((Path(os.environ["XDG_RUNTIME_DIR"]) / "kingstra-spatial-9.json").read_text())
assert data["workspace"] == 9
assert len(data["windows"]) == 2
assert data["windows"][0]["title"] == 'Quoted "title"\nsecond line'
print("ok - overview snapshot is valid JSON, including quoted titles")
PY
python3 tests/smoke/workspace-layout.py
lua tests/smoke/spatial-drag.lua
