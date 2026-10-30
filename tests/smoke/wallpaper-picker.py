#!/usr/bin/env python3
"""Picker regression checks using real images and isolated state; no live apply."""
import argparse
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("picker", ROOT / "config/quickshell/wallpaper/backend.py")
picker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(picker)


class PickerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.folder = self.base / "beelden met spaties"
        self.folder.mkdir()
        self.env = patch.dict(picker.os.environ, {"KINGSTRA_WALLPAPER_DIR": str(self.folder)})
        self.env.start()
        self.addCleanup(self.env.stop)
        for name, value in {"CONFIG": self.base / "config", "CACHE": self.base / "cache/kingstra/wallpaper-picker",
                            "SETTINGS": self.base / "config/kingstra/wallpaper-picker.json"}.items():
            replacement = patch.object(picker, name, value)
            replacement.start()
            self.addCleanup(replacement.stop)

    def capture(self, function, *args):
        with contextlib.redirect_stdout(io.StringIO()) as output:
            function(*args)
        return [json.loads(line) for line in output.getvalue().splitlines()]

    def image(self, name="plaatje.jpg", size=(2400, 1600), color="#bbaa66"):
        path = self.folder / name
        Image.new("RGB", size, color).save(path)
        return path

    def test_library_with_unicode_quotes_duplicates_and_broken_images(self):
        image = self.image('Bos "één".jpg')
        (self.folder / "alias.jpg").symlink_to(image)
        (self.folder / "kapot.png").write_bytes(b"geen plaatje")
        (self.folder / "notities.txt").write_text("hallo")
        events = self.capture(picker.catalog)
        self.assertEqual(len(events[0]["items"]), 2)
        self.assertEqual(sum(e["event"] == "thumbnail-error" for e in events), 1)
        thumb = next(e for e in events if e["event"] == "thumbnail")
        self.assertEqual(thumb["dimensions"], "2400 × 1600")
        with Image.open(Path(picker.urllib.parse.unquote(picker.urllib.parse.urlparse(thumb["thumb"]).path))) as result:
            self.assertLessEqual(result.width, 768)
            self.assertLessEqual(result.height, 480)

    def test_unchanged_files_reuse_cache_and_changed_files_invalidate(self):
        image = self.image()
        first = self.capture(picker.catalog)
        self.assertTrue(any(e["event"] == "thumbnail" for e in first))
        second = self.capture(picker.catalog)
        self.assertFalse(any(e["event"] == "thumbnail" for e in second))
        old_thumb = second[0]["items"][0]["thumb"]
        Image.new("RGB", (800, 600), "red").save(image)
        third = self.capture(picker.catalog)
        self.assertNotEqual(next(e for e in third if e["event"] == "thumbnail")["thumb"], old_thumb)

    def test_preferences_preserve_mode_and_toggle_favorites(self):
        path = str(self.image())
        self.capture(picker.preferences, "mode", "mosaic")
        self.capture(picker.preferences, "favorites", path)
        self.assertTrue(self.capture(picker.catalog)[0]["items"][0]["favorite"])
        self.capture(picker.preferences, "favorites", path)
        state = picker.read_json(picker.SETTINGS)
        self.assertEqual(state, {"mode": "mosaic", "favorites": []})

    def test_colour_sorting_is_default_and_can_be_remembered(self):
        self.assertEqual(self.capture(picker.catalog)[0]["settings"]["sort"], "color")
        self.capture(picker.preferences, "sort", "name")
        self.assertEqual(self.capture(picker.catalog)[0]["settings"]["sort"], "name")

    def test_hsl_hue_buckets_and_saturation_match_skwd(self):
        for color, bucket in [("#ff0000",0), ("#ffff00",2), ("#00ff00",4), ("#0000ff",8), ("#ffffff",99), ("#808080",99), ("#000000",99)]:
            self.assertEqual(picker.color_metrics(color)["hue"], bucket)
        self.assertAlmostEqual(picker.color_metrics("#ff0000")["saturation"], 100)
        self.assertLess(picker.color_metrics("#888080")["saturation"], 10)

    def test_cached_thumbnail_gains_colour_metrics_without_new_decode(self):
        self.image(color="#ff0000")
        events = self.capture(picker.catalog)
        self.assertEqual(next(e for e in events if e["event"] == "thumbnail")["hue"], 0)
        warm = self.capture(picker.catalog)
        self.assertEqual(warm[0]["items"][0]["hue"], 0)
        self.assertAlmostEqual(warm[0]["items"][0]["saturation"], 100)
        self.assertFalse(any(e["event"] == "thumbnail" for e in warm))

    def test_incomplete_thumbnail_metadata_is_rebuilt_after_interrupted_write(self):
        source = self.image(color="#ff0000")
        self.capture(picker.catalog)
        sidecar = picker.CACHE / "thumbs" / (picker.thumbnail_key(source) + ".json")
        sidecar.write_text("{interrupted")
        repaired = self.capture(picker.catalog)
        self.assertFalse(repaired[0]["items"][0]["thumb"])
        thumbnail = next(event for event in repaired if event["event"] == "thumbnail")
        self.assertEqual(thumbnail["hue"], 0)
        self.assertTrue(json.loads(sidecar.read_text())["dimensions"])

    def test_current_effect_uses_original_only_while_effect_active(self):
        image = self.image()
        effect = self.base / "cache/kingstra/theme-wallpapers/paper/x.jpg"
        effect.parent.mkdir(parents=True)
        effect.write_bytes(b"image")
        active = self.base / "cache/skwd-wall/current_wallpaper"
        active.parent.mkdir(parents=True)
        source = self.base / "cache/kingstra/theme-wallpaper-source"
        source.write_text(str(image))
        active.write_text(str(effect))
        self.assertEqual(picker.current_wallpaper(), str(image))
        other = self.image("other.jpg")
        active.write_text(str(other))
        self.assertEqual(picker.current_wallpaper(), str(other))

    def test_search_filters_hosts_and_paginates_without_network_on_cache_hit(self):
        args = argparse.Namespace(query="bos", page=2, sort="toplist", categories="111", purity="100", color="", atleast="", ratios="")
        response = {"data": [{"id": "abc123", "thumbs": {"large": "https://th.wallhaven.cc/lg/ab/abc123.jpg"}, "resolution": "3840x2160"},
                             {"id": "evil12", "thumbs": {"large": "https://example.com/evil.jpg"}}],
                    "meta": {"current_page": 2, "last_page": 8}}
        with patch.object(picker, "remote_json", return_value=response) as request, patch.object(picker, "remote_thumbnail", return_value={"path":"abc123", "thumb":"file:///tmp/t.jpg"}):
            events = self.capture(picker.search, args)
            self.assertEqual(events[0]["page"], 2)
            self.assertEqual(events[0]["lastPage"], 8)
            self.assertEqual([i["id"] for i in events[0]["items"]], ["abc123"])
            self.capture(picker.search, args)
            self.assertEqual(request.call_count, 1)

    def test_failed_download_never_publishes_partial_image(self):
        response = io.BytesIO(b"this is not a JPEG")
        response.url = "https://w.wallhaven.cc/full/ab/wallhaven-abc123.jpg"
        with patch.object(picker, "remote_json", return_value={"data": {"path": response.url}}), patch.object(picker.urllib.request, "urlopen", return_value=response):
            with self.assertRaises(OSError): picker.download("abc123")
        self.assertEqual(list(self.folder.iterdir()), [])

    def test_preview_download_is_cached_without_adding_to_library(self):
        payload=io.BytesIO()
        Image.new("RGB",(160,90),"blue").save(payload,"JPEG")
        response=io.BytesIO(payload.getvalue())
        response.url="https://w.wallhaven.cc/full/ab/wallhaven-abc123.jpg"
        data={"data":{"path":response.url,"resolution":"160x90","uploader":{"username":"maker"},"tags":[{"name":"landscape"}]}}
        with patch.object(picker,"remote_json",return_value=data),patch.object(picker.urllib.request,"urlopen",return_value=response):
            events=self.capture(picker.download,"abc123",True)
        self.assertEqual(events[0]["event"],"preview")
        self.assertEqual(events[0]["tags"],["landscape"])
        self.assertTrue(Path(events[0]["path"]).is_file())
        self.assertEqual(list(self.folder.iterdir()),[])
        with patch.object(picker,"remote_json") as request:
            cached=self.capture(picker.download,"abc123",True)
            request.assert_not_called()
        self.assertEqual(cached[0]["url"],events[0]["url"])

    def test_download_keeps_tags_with_image_and_catalog_reads_them_offline(self):
        payload=io.BytesIO()
        Image.new("RGB",(160,90),"blue").save(payload,"JPEG")
        response=io.BytesIO(payload.getvalue())
        response.url="https://w.wallhaven.cc/full/ab/wallhaven-abc123.jpg"
        data={"data":{"path":response.url,"tags":[{"name":"landscape","alias":"landschap"}],"colors":["#0066cc"]}}
        with patch.object(picker,"remote_json",return_value=data),patch.object(picker.urllib.request,"urlopen",return_value=response):
            event=self.capture(picker.download,"abc123")[0]
        sidecar=picker.metadata_file(event["path"])
        self.assertTrue(sidecar.is_file())
        self.assertEqual(json.loads(sidecar.read_text())["tag_names"],["landscape"])
        item=self.capture(picker.catalog)[0]["items"][0]
        self.assertEqual(item["tags"],["landscape"])
        self.assertEqual(item["tagAliases"],["landschap"])

    def test_remove_sends_image_and_metadata_to_trash_without_applying(self):
        path=self.image("wallhaven-abc123.jpg")
        picker.atomic_json(picker.metadata_file(path),{"source":"wallhaven"})
        def trash(args,**kwargs):
            self.assertEqual(args[:2],["/usr/bin/gio","trash"])
            self.assertEqual(args[2:],[str(path),str(picker.metadata_file(path))])
            for value in args[2:]:Path(value).unlink()
            return type("Result",(),{"returncode":0})()
        with patch.object(picker.shutil,"which",return_value="/usr/bin/gio"),patch.object(picker.subprocess,"run",side_effect=trash):
            event=self.capture(picker.remove,"abc123")[0]
        self.assertEqual(event["event"],"removed")
        self.assertEqual(event["remaining"],"")

    def test_remove_protects_active_wallpaper(self):
        path=self.image("wallhaven-abc123.jpg")
        with patch.object(picker,"current_wallpaper",return_value=str(path)),patch.object(picker.subprocess,"run") as run:
            with self.assertRaisesRegex(ValueError,"andere wallpaper"):picker.remove("abc123")
            run.assert_not_called()

    def test_download_uses_validated_metadata_and_rejects_other_hosts(self):
        with patch.object(picker, "remote_json", return_value={"data": {"path": "https://other.invalid/wallhaven-abc123.jpg"}}):
            with self.assertRaises(ValueError): picker.download("abc123")
        with self.assertRaises(ValueError): picker.download("../../bad")

    def test_save_reuses_full_preview_without_a_second_image_request(self):
        cached = picker.CACHE / "previews/wallhaven-abc123.jpg"
        cached.parent.mkdir(parents=True)
        Image.new("RGB", (160, 90), "blue").save(cached, "JPEG")
        data = {"data": {"path": "https://w.wallhaven.cc/full/ab/wallhaven-abc123.jpg"}}
        with patch.object(picker, "remote_json", return_value=data), patch.object(picker.urllib.request, "urlopen") as request:
            events = self.capture(picker.download, "abc123")
        request.assert_not_called()
        self.assertEqual(Path(events[0]["path"]).read_bytes(), cached.read_bytes())
        self.assertEqual(picker.saved_wallhaven("abc123"), events[0]["path"])

    def test_large_preview_cache_evicts_old_images_but_keeps_active_preview(self):
        folder = picker.CACHE / "previews"
        folder.mkdir(parents=True)
        active, old, newer = [folder / name for name in ["wallhaven-active.jpg", "wallhaven-old.jpg", "wallhaven-new.jpg"]]
        for index, path in enumerate([active, old, newer]):
            path.write_bytes(b"x" * 40)
            os.utime(path, (100 + index, 100 + index))
        picker.trim_previews(active, budget=80)
        self.assertTrue(active.is_file())
        self.assertFalse(old.exists())
        self.assertTrue(newer.is_file())

    def test_apply_preserves_filename_as_single_argument(self):
        image = self.image('Bos "één" $(niet uitvoeren).jpg')
        with patch.object(picker.subprocess, "run") as run:
            run.return_value.returncode = 0
            self.capture(picker.apply, str(image))
            self.assertEqual(run.call_args.args[0][-2:], ["set", str(image)])
            self.assertNotIn("shell", run.call_args.kwargs)


if __name__ == "__main__": unittest.main()
