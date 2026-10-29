#!/usr/bin/env python3
"""Exercise updater routing and ABI migration without network or live outputs."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
SCRIPT=ROOT/"config/shared/scripts/kingstra-build-native-zoom"
PIN="a1e8a0806541640d01503ac861a8a39548de8724"

class NativeZoomBuild(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix="kingstra-build-test-")
        self.addCleanup(self.temp.cleanup)
        self.dir=Path(self.temp.name)
        self.bin=self.dir/"bin";self.bin.mkdir()
        self.destination=self.dir/"native.so"
        self.headers=self.dir/"include/hyprland/src";self.headers.mkdir(parents=True)
        self.env=dict(os.environ,PATH=str(self.bin)+":"+os.environ["PATH"],
                      XDG_CACHE_HOME=str(self.dir/"cache"),
                      KINGSTRA_NATIVE_ZOOM_DESTINATION=str(self.destination),
                      TEST_BUILD_HEADERS=str(self.dir/"include"),
                      TEST_BUILD_LOG=str(self.dir/"calls"))
        scripts={
            "pkg-config":"""import os,sys
print(os.environ['TEST_BUILD_VERSION'] if '--modversion' in sys.argv else os.environ['TEST_BUILD_HEADERS'])
""",
            "git":f"""import sys
from pathlib import Path
if 'init' in sys.argv:Path(sys.argv[-1],'.git').mkdir(parents=True)
if 'rev-parse' in sys.argv:print('{PIN}')
""",
            "cmake":"""import os,sys
from pathlib import Path
if os.getenv('TEST_BUILD_FAIL'):sys.exit(17)
with open(os.environ['TEST_BUILD_LOG'],'a') as log:log.write(' '.join(sys.argv[1:])+'\\n')
if '--build' in sys.argv:
 p=Path(sys.argv[sys.argv.index('--build')+1]);p.mkdir(parents=True,exist_ok=True)
 (p/'libspatialoverview.so').write_text('test binary')
""",
        }
        for name,body in scripts.items():
            path=self.bin/name;path.write_text("#!/usr/bin/env python3\n"+body);path.chmod(0o755)
    def run_build(self,version,fail=False):
        abi={"0.56.2":"aaaa","0.57.0":"bbbb"}.get(version,"cccc")
        (self.headers/"version.h").write_text('#define GIT_COMMIT_HASH    "'+abi+'"\n')
        env=dict(self.env,TEST_BUILD_VERSION=version)
        if fail:env["TEST_BUILD_FAIL"]="1"
        return subprocess.run(["bash",str(SCRIPT)],env=env,text=True,capture_output=True)
    def stamp(self,suffix=".abi"):
        return Path(str(self.destination)+suffix).read_text().splitlines()
    def test_upgrade_preserves_running_build_and_caches_new_version(self):
        old=self.run_build("0.56.2");self.assertEqual(old.returncode,0,old.stderr)
        previous=self.stamp()
        # Simulate an installation predating the indexed stamps.
        Path(str(self.destination)+".aaaa.abi").unlink()
        new=self.run_build("0.57.0");self.assertEqual(new.returncode,0,new.stderr)
        self.assertEqual(self.stamp(".aaaa.abi"),previous)
        current=self.stamp();self.assertEqual(current[0],"bbbb")
        self.assertNotEqual(current[1],previous[1])
        self.assertEqual(self.stamp(".bbbb.abi"),current)
        self.assertTrue(Path(previous[1]).exists())
        self.assertTrue((Path(current[1]).parents[1]/"source/main.cpp").exists())
        calls=(self.dir/"calls").read_text()
        again=self.run_build("0.57.0");self.assertEqual(again.returncode,0,again.stderr)
        self.assertEqual(calls,(self.dir/"calls").read_text())
        unknown=self.run_build("0.58.0")
        self.assertNotEqual(unknown.returncode,0)
        self.assertEqual(self.stamp(),current)
        self.assertEqual(str(self.destination.resolve()),current[1])
    def test_failed_build_keeps_last_working_entry(self):
        old=self.run_build("0.56.2");self.assertEqual(old.returncode,0,old.stderr)
        previous=self.stamp()
        failed=self.run_build("0.57.0",fail=True)
        self.assertNotEqual(failed.returncode,0)
        self.assertEqual(self.stamp(),previous)
        self.assertEqual(str(self.destination.resolve()),previous[1])

if __name__=="__main__":unittest.main()
