#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("profiles", "config/quickshell/settings/screen-profile.py")
profiles = importlib.util.module_from_spec(spec)
spec.loader.exec_module(profiles)


class ProfilesTests(unittest.TestCase):
    def setUp(self):
        self.a = {"name": "DP-1", "serial": "abc", "make": "ACME", "model": "Monitor"}
        self.b = dict(self.a, name="DP-2", serial="def")
        self.data = {"version": 1, "screens": {}}
        self.presets = {"office": {}, "media": {}, "gaming": {}}

    def update(self, monitor, command, *args):
        profiles.change(self.data, monitor, command, args, self.presets, {"name": "office"})

    def test_independent_modes_and_profiles(self):
        self.update(self.a, "mode", "media")
        self.update(self.a, "set", "rail.pins", '["media"]')
        self.update(self.b, "mode", "office")
        self.update(self.a, "mode", "office")
        self.update(self.a, "set", "rail.pins", '["wifi"]')
        a = self.data["screens"][profiles.monitor_key(self.a)]
        b = self.data["screens"][profiles.monitor_key(self.b)]
        self.assertEqual(a["modes"]["media"]["rail"]["pins"], ["media"])
        self.assertEqual(a["modes"]["office"]["rail"]["pins"], ["wifi"])
        self.assertEqual(b["mode"], "office")
        self.update(self.a, "mode", "media")
        self.assertEqual(a["mode"], "media")
        self.assertEqual(b["mode"], "office")

    def test_monitor_identity_survives_connector_change(self):
        self.assertEqual(profiles.monitor_key(dict(self.a, name="DP-9")), profiles.monitor_key(self.a))
        self.assertNotEqual(profiles.monitor_key({"name": "DP-1"}), profiles.monitor_key({"name": "DP-2"}))

    def test_unknown_global_setting_is_rejected(self):
        with self.assertRaises(ValueError):
            self.update(self.a, "set", "powerProfile", '"performance"')

    def test_wallpaper_drift_is_per_screen_not_per_mode(self):
        self.update(self.a, "set", "wallpaperDrift", "false")
        a = self.data["screens"][profiles.monitor_key(self.a)]
        self.assertIs(a["wallpaperDrift"], False)
        self.update(self.a, "mode", "media")
        self.assertIs(a["wallpaperDrift"], False)
        with self.assertRaises(ValueError):
            self.update(self.a, "set", "wallpaperDrift", '"ja"')

    def test_overflow_accepts_only_rail_buttons(self):
        self.update(self.a, "set", "rail.overflow", '["settings", "pins"]')
        a = self.data["screens"][profiles.monitor_key(self.a)]
        self.assertEqual(a["modes"]["office"]["rail"]["overflow"], ["settings", "pins"])
        # Sinds Rail-indeling kan elk railonderdeel achter Meer, ook eigen apps.
        self.update(self.a, "set", "rail.overflow", '["clock", "apps"]')
        with self.assertRaises(ValueError):
            self.update(self.a, "set", "rail.overflow", '["onbekend"]')

    def test_corrupt_preferences_are_not_discarded(self):
        with tempfile.TemporaryDirectory() as folder:
            file = Path(folder) / "profiles.json"
            file.write_text("{broken")
            with patch.object(profiles, "FILE", file):
                with self.assertRaises(ValueError):
                    profiles.load()
            self.assertEqual(file.read_text(), "{broken")


unittest.main()
