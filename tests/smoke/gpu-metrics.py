#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("gpu", "config/quickshell/shellsurface/gpu-metrics.py")
gpu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gpu)


class GpuTests(unittest.TestCase):
    def test_missing_is_not_zero_and_real_zero_is_retained(self):
        with tempfile.TemporaryDirectory() as folder:
            file = Path(folder) / "metric"
            self.assertIsNone(gpu.number(file))
            file.write_text("0")
            self.assertEqual(gpu.number(file), 0)

    def test_suspended_device_never_starts_a_probe(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            device = root / "card0/device"
            (device / "power").mkdir(parents=True)
            (device / "power/runtime_status").write_text("suspended")
            (device / "vendor").write_text("0x10de")
            with patch.object(gpu, "DRM", root), patch.object(gpu, "command") as probe:
                result = gpu.collect()
                probe.assert_not_called()
            self.assertTrue(result[0]["sleeping"])
            self.assertIsNone(result[0]["usage"])

    def test_missing_smi_values_remain_unknown(self):
        self.assertIsNone(gpu.finite("[N/A]"))
        self.assertIsNone(gpu.finite("nan"))
        self.assertEqual(gpu.finite("0"), 0)


unittest.main()
