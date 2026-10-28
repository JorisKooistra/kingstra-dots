#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

path = Path("config/hypr/scripts/workspace-layout.py")
spec = importlib.util.spec_from_file_location("workspace_layout", path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class LayoutTests(unittest.TestCase):
    def state(self, layout, windows=2):
        return {"id": 3, "windows": windows, "tiledLayout": layout}

    def test_disabled_scroll_never_dispatches_despite_stale_preference(self):
        with patch.object(module, "query", return_value=self.state("dwindle")), \
             patch.object(module, "saved", return_value={"3": "scrollen"}), \
             patch.object(module, "dispatch") as dispatch:
            self.assertFalse(module.action("wheel", "down"))
            self.assertEqual(module.current()["preset"], "tegels")
            dispatch.assert_not_called()

    def test_empty_spatial_workspace_does_nothing(self):
        with patch.object(module, "query", return_value=self.state("lua:hyprscroll2d", 0)), \
             patch.object(module, "dispatch") as dispatch:
            self.assertFalse(module.action("panby", "12", "34"))
            dispatch.assert_not_called()

    def test_diagonal_delta_is_one_message(self):
        with patch.object(module, "query", return_value=self.state("lua:hyprscroll2d")), \
             patch.object(module, "dispatch") as dispatch:
            self.assertTrue(module.action("panby", "12.5", "-7.25"))
            dispatch.assert_called_once_with("panby 12.5000 -7.2500")

    def test_failed_application_does_not_save_a_success(self):
        with patch.object(module, "query", return_value=self.state("dwindle")), \
             patch.object(module, "hypr", return_value="ok"), \
             patch.object(module, "save") as save, patch.object(module.time, "sleep"):
            with self.assertRaises(RuntimeError):
                module.apply("scrollen")
            save.assert_not_called()

    def test_unknown_custom_layout_is_not_activated(self):
        with patch.object(module, "query", return_value=self.state("dwindle")), \
             patch.object(module, "hypr", return_value="false") as hypr, \
             patch.object(module, "save") as save:
            with self.assertRaises(RuntimeError):
                module.apply("ruimtelijk")
            self.assertEqual(hypr.call_count, 1)
            save.assert_not_called()

    def test_atomic_preferences_roundtrip(self):
        with tempfile.TemporaryDirectory() as folder, patch.object(module, "STATE", Path(folder)):
            module.save("3", "ruimtelijk")
            self.assertEqual(module.saved(), {"3": "ruimtelijk"})
            self.assertEqual((Path(folder) / "workspace-layouts").read_text(), "3 lua:hyprscroll2d\n")


unittest.main()
