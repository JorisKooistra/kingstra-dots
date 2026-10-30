#!/usr/bin/env python3
"""Colour-pipeline regressions with private config, fake reloads and no live apply."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = ROOT / "config/shared/scripts"


class ColourPipelineTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="kingstra-colours-test-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.config = self.base / "config"
        self.cache = self.base / "cache"
        self.bin = self.base / "bin"
        self.bin.mkdir()
        self.state = self.config / "kingstra/state"
        self.state.mkdir(parents=True)
        self.wallpaper = self.base / 'wallhaven-abc123.jpg'
        Image.new("RGB", (32, 32), "red").save(self.wallpaper)
        self.env = dict(os.environ, XDG_CONFIG_HOME=str(self.config), XDG_CACHE_HOME=str(self.cache),
                        PATH=str(self.bin) + ":" + os.environ["PATH"], TEST_COLOURS_DIR=str(self.base))

    def executable(self, name, source):
        target = self.bin / name
        target.write_text(source)
        target.chmod(0o755)
        return target

    def run_tags(self):
        return subprocess.run(["bash", str(SCRIPTS / "kingstra-wallhaven-tags"), str(self.wallpaper)],
                              env=self.env, capture_output=True, text=True, check=True)

    def test_tags_cache_reuses_metadata_and_serialises_concurrent_fetches(self):
        self.executable("curl", '''#!/usr/bin/env python3
import json,os,time
from pathlib import Path
with (Path(os.environ['TEST_COLOURS_DIR'])/'requests').open('a') as f:f.write('request\\n')
time.sleep(.15)
print(json.dumps({'data':{'id':'abc123','tags':[{'id':1,'name':'bos'}]}}))
''')
        (self.state / "wallpaper.json").write_text(json.dumps({"path": str(self.wallpaper)}))
        commands = ["bash", str(SCRIPTS / "kingstra-wallhaven-tags"), str(self.wallpaper)]
        first = subprocess.Popen(commands, env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        second = subprocess.Popen(commands, env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        for process in [first, second]:
            out, err = process.communicate(timeout=8)
            self.assertEqual(process.returncode, 0, err)
        self.assertEqual((self.base / "requests").read_text().splitlines(), ["request"])
        self.assertEqual(json.loads((self.state / "wallpaper.json").read_text())["tags"], ["bos"])
        index = self.state / "wallhaven-tags.json"
        data = json.loads(index.read_text())
        data["abc123"]["fetched_at"] = "2000-01-01T00:00:00+00:00"
        index.write_text(json.dumps(data))
        self.run_tags()
        self.assertEqual(len((self.base / "requests").read_text().splitlines()), 2)

    def apply_fixture(self):
        for name in ["kingstra/modes", "kingstra/themes", "quickshell"]:
            (self.config / name).mkdir(parents=True, exist_ok=True)
        (self.config / "kingstra/modes/office.toml").write_text("")
        theme = self.config / "kingstra/themes/organic.toml"
        theme.write_text('[meta]\nname="Organic"\n')
        self.executable("pgrep", "#!/bin/sh\nexit 1\n")
        self.executable("kingstra-session-update", "#!/bin/sh\nexit 0\n")
        self.executable("kingstra-matugen-run", '''#!/usr/bin/env python3
import json,os,sys,time
from pathlib import Path
base=Path(os.environ['TEST_COLOURS_DIR']);config=Path(os.environ['XDG_CONFIG_HOME'])
wall=sys.argv[sys.argv.index('--wallpaper')+1]
if '--resolved-json' in sys.argv:
 print(json.dumps(dict(theme='organic',theme_file=str(config/'kingstra/themes/organic.toml'),wallpaper=wall,scheme_type='scheme-content',mode='dark',color_index=0)))
else:
 with (base/'generations').open('a') as f:f.write('generate\\n')
 if (base/'fail-once').exists():
  (base/'fail-once').unlink();sys.exit(1)
 (config/'quickshell/colors.json').write_text('{"primary":"#112233"}')
 print('{"colors":{"primary":"#112233"}}')
''')
        self.executable("kingstra-wallhaven-tags", '''#!/usr/bin/env python3
import os,time
from pathlib import Path
base=Path(os.environ['TEST_COLOURS_DIR'])
(base/'tags-started').touch()
time.sleep(.7)
''')
        source = (SCRIPTS / "apply-shell-state").read_text()
        source = source.replace('${HOME}/.local/bin', str(self.bin)).replace('$HOME/.local/bin', str(self.bin))
        source = source.replace('LOCK_FILE="/tmp/apply-shell-state.lock"', 'LOCK_FILE="' + str(self.base / 'apply.lock') + '"')
        target = self.base / "apply-shell-state"
        target.write_text(source)
        return ["bash", str(target), "--wallpaper", str(self.wallpaper)]

    def test_colours_publish_before_tags_and_duplicate_hook_is_coalesced(self):
        command = self.apply_fixture()
        first = subprocess.Popen(command, env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        deadline = time.monotonic() + 5
        while not (self.base / "tags-started").exists() and time.monotonic() < deadline:
            time.sleep(.02)
        self.assertTrue((self.base / "tags-started").exists())
        self.assertIsNone(first.poll(), "slow metadata fixture did not run")
        self.assertEqual(json.loads((self.config / "quickshell/colors.json").read_text())["primary"], "#112233")
        second = subprocess.Popen(command, env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        for process in [first, second]:
            out, err = process.communicate(timeout=8)
            self.assertEqual(process.returncode, 0, err)
        self.assertEqual(len((self.base / "generations").read_text().splitlines()), 1)
        # A renderer hook may arrive just after the explicit apply completed.
        subprocess.run(command + ["--renderer-hook"], env=self.env, capture_output=True, check=True)
        self.assertEqual(len((self.base / "generations").read_text().splitlines()), 1)
        # An explicit refresh after completion must not be swallowed.
        subprocess.run(command, env=self.env, capture_output=True, check=True)
        self.assertEqual(len((self.base / "generations").read_text().splitlines()), 2)

    def test_failed_generation_is_not_remembered_as_success(self):
        command = self.apply_fixture()
        (self.base / "fail-once").touch()
        subprocess.run(command, env=self.env, capture_output=True, check=True)
        self.assertFalse((self.cache / "kingstra/last-shell-apply").exists())
        subprocess.run(command, env=self.env, capture_output=True, check=True)
        self.assertTrue((self.cache / "kingstra/last-shell-apply").is_file())

    @unittest.skipUnless(shutil.which("matugen") and shutil.which("magick"), "requires Matugen and ImageMagick")
    def test_cached_accent_calculation_preserves_palette_and_invalidates_on_image_change(self):
        config = self.config
        (config / "matugen").mkdir()
        (config / "quickshell").mkdir()
        (config / "quickshell/theme.json").write_text('{"theme":"organic"}')
        (config / "kingstra/themes").mkdir()
        shutil.copy2(ROOT / "config/kingstra/themes/organic.toml", config / "kingstra/themes/organic.toml")
        (config / "matugen/templates").symlink_to(ROOT / "config/matugen/templates")
        (config / "matugen/config.toml").write_text('''scheme_type = "scheme-content"
mode = "dark"
color_index = 1
[templates.hyprland]
input_path = "''' + str(config / "matugen/templates/hypr-colors.lua") + '''"
output_path = "unused"
[templates.quickshell]
input_path = "''' + str(config / "matugen/templates/quickshell-colors.json") + '''"
output_path = "unused"
''')
        real_magick = shutil.which("magick")
        self.executable("magick", '#!/bin/sh\nprintf "histogram\\n" >> "'+str(self.base/'histograms')+'"\nexec "'+real_magick+'" "$@"\n')
        command = [str(SCRIPTS / "kingstra-matugen-run"), "--wallpaper", str(self.wallpaper), "--json", "hex"]
        first = subprocess.run(command, env=self.env, capture_output=True, text=True, check=True).stdout
        calls = (self.base / "histograms").read_text().splitlines()
        second = subprocess.run(command, env=self.env, capture_output=True, text=True, check=True).stdout
        self.assertEqual(json.loads(first), json.loads(second))
        self.assertEqual((self.base / "histograms").read_text().splitlines(), calls)
        Image.new("RGB", (32, 32), "blue").save(self.wallpaper)
        changed = subprocess.run(command, env=self.env, capture_output=True, text=True, check=True).stdout
        self.assertGreater(len((self.base / "histograms").read_text().splitlines()), len(calls))
        self.assertNotEqual(json.loads(first), json.loads(changed))


if __name__ == "__main__":
    unittest.main()
