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
assert len(data["windows"]) == 3
assert data["windows"][0]["title"] == 'Quoted "title"\nsecond line'
print("ok - overview snapshot is valid JSON, including quoted titles")
assert any(w["address"] == "0xF" and w["floating"] for w in data["windows"])
print("ok - floating windows are included in the overview")
floating_only=json.loads((Path(os.environ["XDG_RUNTIME_DIR"])/"kingstra-spatial-11.json").read_text())
assert len(floating_only["windows"])==1 and floating_only["windows"][0]["floating"]
print("ok - floating-only workspace snapshot contains the floating app")
PY
python3 tests/smoke/workspace-layout.py
lua tests/smoke/spatial-drag.lua
lua tests/smoke/spatial-storage.lua
lua tests/smoke/spatial-binds.lua
lua tests/smoke/native-zoom.lua
lua tests/smoke/native-zoom-abi.lua
python3 tests/smoke/native-zoom-build.py
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/smoke/qml -o -,txt
