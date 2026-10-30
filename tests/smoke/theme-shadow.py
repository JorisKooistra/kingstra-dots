#!/usr/bin/env python3
"""Theme switches publish matching live/persistent shadows and restore defaults.

All configuration and commands are private fixtures; no live desktop is touched.
"""
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix="kingstra-theme-shadow-") as tmp:
    base = Path(tmp)
    config = base / ".config"
    (config / "kingstra").mkdir(parents=True)
    (config / "kingstra/themes").symlink_to(ROOT / "config/kingstra/themes")
    (config / "kitty").mkdir()
    (config / "kitty/kitty.conf").write_text("# fixture\n")
    commands = base / ".local/bin"
    commands.mkdir(parents=True)
    (commands / "kingstra-theme-read").symlink_to(ROOT / "config/shared/scripts/kingstra-theme-read.py")
    for name in ["gsettings", "notify-send", "quickshell", "skwd", "apply-shell-state"]:
        path = commands / name
        path.write_text("#!/bin/sh\nexit 0\n")
        path.chmod(0o755)
    hypr = commands / "hyprctl"
    hypr.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$TEST_HYPR_LOG"\n')
    hypr.chmod(0o755)
    calls = base / "hypr-calls"
    env = dict(os.environ, HOME=str(base), XDG_CONFIG_HOME=str(config),
               XDG_CACHE_HOME=str(base / ".cache"), TEST_HYPR_LOG=str(calls),
               PATH=str(commands) + os.pathsep + os.environ["PATH"])
    # Leave Matte for every other family, verifying the shadow cannot leak.
    for theme in ["matte", "organic", "matte", "paper", "matte", "neon", "mono", "mono-accent"]:
        calls.write_text("")
        result = subprocess.run(["bash", str(ROOT / "config/shared/scripts/kingstra-theme-switch"), theme],
                                env=env, capture_output=True, text=True, timeout=20)
        assert result.returncode == 0, result.stdout + result.stderr
        generated = config / "hypr/lua/theme.lua"
        subprocess.run(["luac", "-p", str(generated)], check=True)
        shadow = 'shadow = { range = 8, color = "rgba(00000047)" }' if theme == "matte" else 'shadow = { range = 12, color = "rgba(000000cc)" }'
        assert shadow in generated.read_text(), (theme, generated.read_text())
        assert shadow in calls.read_text(), (theme, calls.read_text())
        assert json.loads((config / "quickshell/theme.json").read_text())["theme"] == theme
print("Theme shadows OK: live/persistent settings match; all other themes restore defaults")
