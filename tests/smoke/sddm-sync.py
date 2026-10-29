#!/usr/bin/env python3
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


def load(name, path):
    loader = importlib.machinery.SourceFileLoader(name, str(ROOT / path))
    spec = importlib.util.spec_from_loader(name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


sync = load("sddm_sync", "config/shared/scripts/kingstra-sddm-sync")
xsetup = load("sddm_xsetup", "config/sddm/Xsetup.py")


class SddmTests(unittest.TestCase):
    def test_system_install_backs_up_and_installs_without_service_restart(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            stage = base / "stage"; (stage / "theme").mkdir(parents=True)
            (stage / "theme/Main.qml").write_text("new theme")
            (stage / "Xsetup.py").write_text("new setup")
            (stage / "kingstra.conf").write_text("[Theme]\nCurrent=kingstra\n")
            theme = base / "system/theme"; theme.mkdir(parents=True)
            (theme / "Main.qml").write_text("old theme")
            conf = base / "system/zz-kingstra.conf"; conf.write_text("old config")
            with patch.multiple(sync, THEME=theme, CONF=conf, XSETUP=base / "system/Xsetup", BACKUPS=base / "backups"), patch.object(sync.os, "geteuid", return_value=0), patch.object(sync.os, "chown"), patch.object(sync.subprocess, "run") as run:
                sync.install_system(stage, 1000, 1000)
                run.assert_not_called()
            self.assertEqual((theme / "Main.qml").read_text(), "new theme")
            self.assertEqual((next((base / "backups").iterdir()) / "theme/Main.qml").read_text(), "old theme")
            self.assertEqual(theme.stat().st_mode & 0o777, 0o755)
            self.assertEqual((base / "system/Xsetup").stat().st_mode & 0o777, 0o755)
            self.assertIn("Current=kingstra", conf.read_text())

    def test_wallpaper_is_copied_out_of_private_home_and_updated(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            theme = base / "theme"; theme.mkdir()
            cache = base / "cache/skwd-wall"; cache.mkdir(parents=True)
            config = base / "config/matugen/generated"; config.mkdir(parents=True)
            (config / "sddm-colors.qml").write_text("palette")
            wallpaper = base / "wall #1.jpg"; wallpaper.write_bytes(b"first")
            (cache / "current_wallpaper").write_text(str(wallpaper) + "\n")
            with patch.dict(os.environ, {"XDG_CONFIG_HOME": str(base / "config"), "XDG_CACHE_HOME": str(base / "cache")}), patch.object(sync, "hypr_json", return_value=None):
                sync.sync(theme)
                self.assertEqual((theme / "background.img").read_bytes(), b"first")
                self.assertIn("background=background.img", (theme / "theme.conf").read_text())
                self.assertEqual((theme / "Colors.qml").read_text(), "palette")
                wallpaper.write_bytes(b"second")
                sync.sync(theme)
                self.assertEqual((theme / "background.img").read_bytes(), b"second")

    def test_serials_map_different_connector_names_and_keep_order(self):
        profile = {"monitors": [
            {"name": "DP-1", "serial": "right ", "width": 1920, "height": 1080, "x": 3840, "y": 0},
            {"name": "DP-3", "serial": "middle", "width": 1920, "height": 1080, "x": 1920, "y": 0, "focused": True},
            {"name": "DP-4", "serial": "left", "width": 1920, "height": 1080, "x": 0, "y": 0}]}
        command = xsetup.display_command(profile, {"DP-0": "right", "DP-2": "middle", "DP-5": "left"})
        groups = " ".join(command).split("--output ")[1:]
        self.assertIn("DP-0 --mode 1920x1080 --pos 3840x0", groups[0])
        self.assertIn("DP-2 --mode 1920x1080 --pos 1920x0", groups[1])
        self.assertIn("--primary", groups[1])
        self.assertIn("DP-5 --mode 1920x1080 --pos 0x0", groups[2])

    def test_disconnected_monitors_are_skipped(self):
        self.assertEqual(xsetup.display_command({"monitors": [
            {"name": "unplugged", "serial": "missing"}]}, {"eDP-1": ""}), ["/usr/bin/xrandr"])

    def test_edid_serials_are_decoded(self):
        edid = bytearray(128)
        edid[54:72] = b"\0\0\0\xff\0" + b"407TOUH03166\n "
        lines = ["DP-5 connected primary 1920x1080+0+0", "\tEDID:"]
        lines += ["\t\t" + edid.hex()[i:i+32] for i in range(0, 256, 32)]
        lines += ["DP-0 disconnected"]
        self.assertEqual(xsetup.outputs_from_xrandr("\n".join(lines)), {"DP-5": "407TOUH03166"})


if __name__ == "__main__":
    unittest.main()
