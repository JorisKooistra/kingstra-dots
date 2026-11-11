#!/usr/bin/env python3
"""Own photos in the wallpaper folder get offline tags; Wallhaven sidecars stay."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
BACKEND = ROOT / "config/quickshell/wallpaper/backend.py"


class AutotagTests(unittest.TestCase):
    def setUp(self):
        self.base = Path(tempfile.mkdtemp(prefix="kingstra-autotag-test-"))
        self.addCleanup(shutil.rmtree, self.base)
        self.folder = self.base / "Wallpapers"
        (self.folder / "video").mkdir(parents=True)
        (self.base / "config/skwd-wall").mkdir(parents=True)
        (self.base / "config/skwd-wall/config.json").write_text(json.dumps({"paths": {"wallpaper": str(self.folder)}}))
        self.env = dict(os.environ, XDG_CONFIG_HOME=str(self.base / "config"), XDG_CACHE_HOME=str(self.base / "cache"))

    def run_backend(self, *args):
        result = subprocess.run(["python3", str(BACKEND), *args], env=self.env, capture_output=True, text=True, timeout=120)
        self.assertEqual(result.returncode, 0, result.stderr)
        return [json.loads(line) for line in result.stdout.splitlines() if line.startswith("{")]

    def sidecar(self, name):
        return json.loads((self.folder / (name + ".json")).read_text())

    def test_photo_gets_colour_shape_and_exif_tags(self):
        image = Image.new("RGB", (4000, 3000), (40, 110, 220))
        exif = image.getexif()
        exif[271], exif[272], exif[306] = "Google", "Pixel 7", "2024:07:14 20:31:00"
        image.save(self.folder / "IMG_20240714_strand-zandvoort.jpg", exif=exif)
        Image.new("RGB", (3440, 1440), (15, 15, 15)).save(self.folder / "nacht.png")
        (self.folder / "kapot.jpg").write_bytes(b"\xff\xd8\xff niet af")
        self.assertEqual(self.run_backend("autotag")[-1]["tagged"], 2)
        tags = self.sidecar("IMG_20240714_strand-zandvoort.jpg")["tag_names"]
        for tag in ["strand", "zandvoort", "blauw", "liggend", "4k", "eigen foto", "2024", "juli", "zomer", "avond"]:
            self.assertIn(tag, tags)
        self.assertNotIn("img", tags)
        dark = self.sidecar("nacht.png")
        self.assertIn("donker", dark["tag_names"])
        self.assertIn("ultrawide", dark["tag_names"])
        self.assertIn("dark", [tag["alias"] for tag in dark["tags"]])
        self.assertFalse((self.folder / "kapot.jpg.json").exists())

    def test_existing_sidecar_is_left_alone_and_catalog_reports_tags(self):
        Image.new("RGB", (64, 64), "red").save(self.folder / "eigen.jpg")
        (self.folder / "eigen.jpg.json").write_text(json.dumps({"source": "pexels", "tag_names": ["hand"]}))
        Image.new("RGB", (1920, 1080), (230, 120, 20)).save(self.folder / "oranje.jpg")
        events = self.run_backend("catalog")
        self.assertEqual(self.sidecar("eigen.jpg")["tag_names"], ["hand"])
        updates = {Path(event["path"]).name: event for event in events if event["event"] == "tags"}
        self.assertEqual(list(updates), ["oranje.jpg"])
        self.assertIn("oranje", updates["oranje.jpg"]["tags"])
        self.assertIn("orange", updates["oranje.jpg"]["tagAliases"])
        # Second catalog: tags come from the sidecar, nothing is redone.
        events = self.run_backend("catalog")
        self.assertFalse([event for event in events if event["event"] == "tags"])
        item = next(item for item in events[0]["items"] if item["name"] == "oranje.jpg")
        self.assertIn("warm", item["tags"])

    @unittest.skipUnless(shutil.which("ffmpeg"), "ffmpeg ontbreekt")
    def test_video_is_tagged_from_its_frame(self):
        subprocess.run(["ffmpeg", "-v", "error", "-f", "lavfi", "-i", "color=c=green:s=640x360:d=1",
                        str(self.folder / "video/bos.mp4")], check=True)
        self.run_backend("autotag")
        tags = json.loads((self.folder / "video/bos.mp4.json").read_text())["tag_names"]
        for tag in ["bos", "groen", "video"]:
            self.assertIn(tag, tags)


if __name__ == "__main__":
    unittest.main()
