#!/usr/bin/env python3
"""Parkeren en terughalen tegen een nagebootste Hyprland (Lua-dispatches)."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

path = Path("config/hypr/scripts/park-window.py")
spec = importlib.util.spec_from_file_location("park_window", path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class FakeHypr:
    def __init__(self):
        self.clients = [
            {"address": "0xa1", "title": "Mail", "class": "thunderbird", "floating": False,
             "workspace": {"id": 3, "name": "3"}},
            {"address": "0xb2", "title": "Notities", "class": "obsidian", "floating": True,
             "workspace": {"id": -98, "name": "special:kladblok"}},
        ]
        self.active = "0xa1"
        self.active_ws = {"id": 5, "name": "5"}
        self.dispatched = []

    def __call__(self, *args):
        if args[0] == "dispatch":
            expr = args[1]
            self.dispatched.append(expr)
            if "hl.dsp.window.move" in expr:
                target = json.loads(expr.split("workspace = ", 1)[1].split(", follow", 1)[0])
                address = expr.split('"address:', 1)[1].split('"', 1)[0]
                for c in self.clients:
                    if c["address"] == address:
                        name = target[5:] if target.startswith("name:") else target
                        c["workspace"] = {"id": int(name) if name.isdigit() else -1, "name": name}
            return "ok"
        if args[0] == "clients":
            return json.dumps(self.clients)
        if args[0] == "activewindow":
            return json.dumps(next(c for c in self.clients if c["address"] == self.active))
        if args[0] == "activeworkspace":
            return json.dumps(self.active_ws)
        raise AssertionError(args)


class ParkTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.fake = FakeHypr()
        self.patches = [patch.object(module, "STATE", Path(self.tmp.name) / "parked.json"),
                        patch.object(module, "RUNTIME", Path(self.tmp.name)),
                        patch.object(module, "hypr", self.fake),
                        patch.object(module, "feedback", lambda *a: None)]
        for p in self.patches:
            p.start()

    def tearDown(self):
        for p in self.patches:
            p.stop()
        self.tmp.cleanup()

    def test_park_then_restore_returns_to_own_workspace(self):
        self.assertTrue(module.park())
        self.assertEqual(self.fake.clients[0]["workspace"]["name"], "special:geparkeerd")
        self.assertIn("follow = false", self.fake.dispatched[0])
        rows = module.parked_clients()
        self.assertEqual([r["address"] for r in rows], ["0xa1"])
        self.assertEqual(rows[0]["workspace"], "3")
        module.main(["last"])
        self.assertEqual(self.fake.clients[0]["workspace"]["name"], "3")
        self.assertIn('hl.dsp.focus({ window = "address:0xa1" })', self.fake.dispatched[-1])
        self.assertEqual(module.parked_clients(), [])

    def test_window_from_special_comes_back_on_current_workspace(self):
        module.park("0xb2")
        module.restore("0xb2")
        self.assertEqual(self.fake.clients[1]["workspace"]["name"], "5")

    def test_parking_twice_is_harmless(self):
        module.park()
        self.fake.active = "0xa1"
        self.assertFalse(module.park())

    def test_closed_windows_drop_out_of_the_list(self):
        module.park()
        self.fake.clients.pop(0)
        self.assertEqual(module.parked_clients(), [])
        self.assertEqual(module.load(), {})

    def test_restore_rejects_garbage(self):
        with self.assertRaises(ValueError):
            module.restore("0xa1; rm -rf")

    def test_last_with_nothing_parked_does_nothing(self):
        module.main(["last"])
        self.assertEqual(self.fake.dispatched, [])


unittest.main()
