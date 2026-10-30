#!/usr/bin/env python3
"""Exercise the complete Quickshell picker without touching the desktop.

Uses real Qt mouse/key/wheel delivery in an offscreen Window. With Xvfb it also
checks the actual shader output through an actual OpenGL context.
Only PanelWindow/layer-shell configuration is adapted; the production controls,
camera, shaders and worker catalog/preferences are loaded unchanged. Wallhaven
responses and wallpaper application use deterministic, private fixtures.
Requires quickshell, QtTest, qsb, Pillow and a software OpenGL driver.
"""
import argparse
import colorsys
import json
import os
from pathlib import Path
import shutil
import select
import subprocess
import tempfile
import time

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "config/quickshell"

HARNESS = '''import QtQuick
import Quickshell
import QtTest
import Quickshell.Io
import "wallpaper"
ShellRoot {
    PickerWindow { id: picker }
    TestCase { id: input; parent: picker.contentItem; name: "PickerIntegration"; when: false }
    function named(item, name) {
        if (item.objectName === name) return item;
        for (let child of item.children || []) { let found = named(child, name); if (found) return found; }
        return null;
    }
    IpcHandler {
        target: "harness"
        function clickNamed(name: string): string {
            let item = named(picker.contentItem, name);
            if (!item || !item.visible) return "missing or hidden: " + name;
            let p = item.mapToItem(picker.contentItem, item.width/2, item.height/2);
            input.mouseClick(item, item.width/2, item.height/2, Qt.LeftButton, Qt.NoModifier);
            return JSON.stringify({x:p.x,y:p.y});
        }
        function click(x: int, y: int): void { input.mouseClick(picker.contentItem,x,y,Qt.LeftButton,Qt.NoModifier); }
        function hover(x: int, y: int): void { input.mouseMove(picker.contentItem,x,y,5); }
        function wheel(x: int, y: int, delta: int): void { input.mouseWheel(picker.contentItem,x,y,0,delta,Qt.NoButton,Qt.NoModifier,5); }
        function drag(x: int, y: int, dx: int, dy: int): void { input.mouseDrag(picker.contentItem,x,y,dx,dy,Qt.LeftButton,Qt.NoModifier,10); }
        function key(code: int): void { input.keyClick(code,Qt.NoModifier,5); }
        function text(value: string): void {
            let field=named(picker.contentItem,"search"); field.text=value; field.forceActiveFocus();
        }
        function keyText(name: string, value: string): void {
            let field=named(picker.contentItem,name); field.text=value; field.forceActiveFocus();
        }
        function source(id: string): string {
            let control=named(picker.contentItem,"source-selector");
            if (!control.visible) return "tabs";
            let index=picker.allSources.findIndex(source=>source.id===id);
            input.mouseClick(control,control.width/2,control.height/2,Qt.LeftButton,Qt.NoModifier);
            input.keyClick(Qt.Key_Home,Qt.NoModifier);
            for (let i=0;i<index;i++) input.keyClick(Qt.Key_Down,Qt.NoModifier);
            input.keyClick(Qt.Key_Return,Qt.NoModifier);
            return "compact";
        }
        function previewGeometry(): string {
            let image=named(picker.contentItem,"preview-image");
            let p=image.mapToItem(picker.contentItem,0,0);
            return JSON.stringify({x:p.x,y:p.y,width:image.width,height:image.height,paintedWidth:image.paintedWidth,paintedHeight:image.paintedHeight,status:image.status});
        }
        function topic(index: int): void {
            let field=named(picker.contentItem,"remote-topic");field.currentIndex=index;field.activated(index);
        }
        function combo(name: string, index: int): void {
            let field=named(picker.contentItem,name);field.currentIndex=index;field.activated(index);
        }
        function capture(path: string): void { picker.contentItem.grabToImage(result=>result.saveToFile(path)); }
        function resize(w: int, h: int): void { picker.width=w;picker.height=h; }
    }
}
'''


def setup(base):
    farm = base / "quickshell"
    farm.mkdir()
    for entry in SOURCE.iterdir():
        if entry.name != "wallpaper":
            if entry.is_file(): shutil.copy2(entry, farm / entry.name)
            else: (farm / entry.name).symlink_to(entry)
    wallpaper = farm / "wallpaper"
    wallpaper.mkdir()
    for entry in (SOURCE / "wallpaper").iterdir():
        if entry.name not in {"PickerWindow.qml", "backend.py"}:
            # Snapshot the production sources so unrelated live edits cannot
            # hot-reload QtTest's singleton halfway through an input sequence.
            if entry.is_file(): shutil.copy2(entry, wallpaper / entry.name)
    source = (SOURCE / "wallpaper/PickerWindow.qml").read_text()
    source = source.replace("import QtQuick\n", "import QtQuick\nimport QtQuick.Window\n", 1)
    start = source.index("PanelWindow {")
    end = source.index("    MatugenColors", start)
    source = source[:start] + "Window {\n    id: root\n    width: 1920; height: 1080; visible: true\n    color: \"transparent\"\n" + source[end:]
    (wallpaper / "PickerWindow.qml").write_text(source)
    (wallpaper / "backend.py").write_text(
        "import runpy\nrunpy.run_path(" + repr(str(ROOT / "tests/integration/wallpaper-picker-worker.py")) + ",run_name='__main__')\n")
    (farm / "Harness.qml").write_text(HARNESS)
    library = base / "library"
    library.mkdir()
    for index in range(48):
        color = tuple(round(channel * 255) for channel in colorsys.hsv_to_rgb(index / 48, .75, .8))
        image = Image.new("RGB", (960, 600), color)
        draw = ImageDraw.Draw(image)
        draw.polygon([(0, 600), (480, 100), (960, 600)], fill=tuple(c // 2 for c in color))
        draw.text((100, 100), f"Wallpaper {index}", fill="white", font_size=44)
        image.save(library / f"fixture-{index:02}.jpg")
    (base / "config/quickshell").mkdir(parents=True)
    (base / "config/quickshell/colors.json").write_text('{"primary":"#88aaff"}')
    palette = base / "config/kingstra/state/matugen-palette.json"
    palette.parent.mkdir(parents=True)
    palette.write_text("{}")
    runtime = base / "runtime"
    runtime.mkdir(mode=0o700)
    env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), XDG_CONFIG_HOME=str(base / "config"),
               XDG_CACHE_HOME=str(base / "cache"), KINGSTRA_WALLPAPER_DIR=str(library),
               KINGSTRA_PICKER_TEST_DIR=str(base), QT_QPA_PLATFORM="offscreen", QSG_RHI_BACKEND="opengl",
               QT_QPA_OFFSCREEN_NO_GLX="1", LIBGL_ALWAYS_SOFTWARE="1")
    test_bin = base / "bin"
    test_bin.mkdir()
    clipboard = test_bin / "wl-copy"
    clipboard.write_text("#!/usr/bin/env python3\nimport os,sys\nfrom pathlib import Path\n(Path(os.environ['KINGSTRA_PICKER_TEST_DIR'])/'clipboard.txt').write_text(sys.argv[1])\n")
    clipboard.chmod(0o755)
    env["PATH"] = str(test_bin) + ":" + env["PATH"]
    env.pop("WAYLAND_DISPLAY", None)
    env.pop("DISPLAY", None)
    env["QT_QUICK_BACKEND"] = "software"
    env["QSG_INFO"] = "1"
    qsb = shutil.which("qsb") or "/usr/lib/qt6/bin/qsb"
    for name, variable in [("card.frag", "KINGSTRA_PICKER_SHADER"), ("card.vert", "KINGSTRA_PICKER_VERTEX_SHADER")]:
        target = base / (name + ".qsb")
        subprocess.run([qsb, "--glsl", "100 es,120,150", "-o", str(target), str(SOURCE / "wallpaper" / name)], check=True)
        env[variable] = str(target)
    return farm / "Harness.qml", env


class Picker:
    def __init__(self, base, xvfb=None, live_wallhaven=False):
        self.base = base
        self.qml, self.env = setup(base)
        if live_wallhaven:
            # Read the existing API settings; writes/cache/library remain private.
            configured = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "skwd-wall/config.json"
            target = base / "config/skwd-wall/config.json"
            target.parent.mkdir(parents=True)
            if configured.is_file():
                target.symlink_to(configured)
            self.env["KINGSTRA_PICKER_LIVE_API"] = "1"
        self.server = None
        self.rendered = bool(xvfb)
        if xvfb:
            read_fd, write_fd = os.pipe()
            self.server_log = (base / "xvfb.log").open("w")
            self.server = subprocess.Popen([str(xvfb), "-displayfd", str(write_fd), "-screen", "0", "1920x1080x24", "-nolisten", "tcp", "-noreset"],
                                           pass_fds=(write_fd,), stdout=self.server_log, stderr=subprocess.STDOUT)
            os.close(write_fd)
            # X servers may write the number and newline separately. Closing
            # the read end after only the first byte makes Xvfb exit on EPIPE.
            payload, deadline = b"", time.monotonic() + 8
            while b"\n" not in payload and time.monotonic() < deadline:
                if not select.select([read_fd], [], [], max(0, deadline - time.monotonic()))[0]: break
                chunk = os.read(read_fd, 64)
                if not chunk: break
                payload += chunk
            display = payload.decode().strip() if b"\n" in payload else ""
            os.close(read_fd)
            if not display:
                self.server.terminate()
                raise RuntimeError((base / "xvfb.log").read_text())
            self.env.update(QT_QPA_PLATFORM="xcb", QT_QUICK_BACKEND="rhi", DISPLAY=":" + display)
        self.log = (base / "quickshell.log").open("w")
        self.process = subprocess.Popen(["quickshell", "--no-duplicate", "-p", str(self.qml)], env=self.env, stdout=self.log, stderr=subprocess.STDOUT)
        try:
            self.wait(lambda s: s["count"] == 48 and not s["loading"], "initial catalog")
        except Exception:
            self.close()
            raise

    def ipc(self, target, method, *args):
        result = subprocess.run(["quickshell", "ipc", "--any-display", "-p", str(self.qml), "call", target, method, *map(str, args)],
                                env=self.env, capture_output=True, text=True, timeout=8)
        if result.returncode:
            raise RuntimeError(result.stderr or result.stdout)
        return result.stdout.strip()

    def state(self):
        return json.loads(self.ipc("picker", "inspect"))

    def wait(self, predicate, label, timeout=10):
        deadline = time.monotonic() + timeout
        state = None
        while time.monotonic() < deadline:
            try:
                state = self.state()
                if predicate(state):
                    return state
            except (RuntimeError, json.JSONDecodeError):
                if self.process.poll() is not None:
                    break
            time.sleep(.08)
        raise AssertionError(f"Timeout: {label}\n{state}\n{(self.base / 'quickshell.log').read_text()[-3000:]}")

    def click(self, name):
        if name.startswith("source-") and self.ipc("harness", "source", name.removeprefix("source-")) == "compact":
            return {}
        result = self.ipc("harness", "clickNamed", name)
        assert not result.startswith("missing"), result
        return json.loads(result)

    def wheel(self, state, delta):
        v = state["viewport"]
        self.ipc("harness", "wheel", round(v["x"] + v["width"] / 2), round(v["y"] + v["height"] / 2), delta)

    def picture(self):
        state = self.state()
        v, p = state["viewport"], state["motion"]["selectionPoint"]
        self.ipc("harness", "click", round(v["x"] + p["x"]), round(v["y"] + p["y"]))

    def tile_action(self, action="download"):
        state=self.state()
        v,point=state["viewport"],state["motion"]["selectionPoint"]
        if state["mode"]=="hex":height=state["motion"]["hexHeight"]
        elif state["mode"]=="wall":height=v["width"]/state["motion"]["columns"]*.62-12
        elif state["mode"]=="coverflow":height=state["motion"]["currentWidth"]*.64
        else:raise AssertionError("action geometry fixture expects hex/grid/coverflow")
        width = 104 if state["chosenPath"] else 68
        offset = {"apply":16,"download":52,"remove":88}[action] - width/2
        x,y=round(v["x"]+point["x"]+offset),round(v["y"]+point["y"]-height/2+26)
        self.ipc("harness","hover",x,y)
        self.ipc("harness","click",x,y)

    def capture(self, name):
        path = self.base / (name + ".png")
        self.ipc("harness", "capture", path)
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            try:
                with Image.open(path) as image:
                    image.load()
                    if self.rendered and name in {"hexagons", "grid", "compact"}:
                        v = self.state()["viewport"]
                        crop = image.crop((round(v["x"]), round(v["y"]), round(v["x"] + v["width"]), round(v["y"] + v["height"]))).convert("HSV")
                        pixels = list(crop.get_flattened_data()) if hasattr(crop, "get_flattened_data") else list(crop.getdata())
                        fraction = sum(saturation > 85 and value > 55 for _, saturation, value in pixels) / max(1, len(pixels))
                        assert fraction > .08, f"Missing shader images in {name}: {fraction:.1%}"
                return
            except (OSError, ValueError):
                time.sleep(.1)
        raise AssertionError(f"Screenshot failed: {path}")

    def close(self):
        self.process.terminate()
        try:
            self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait()
        self.log.close()
        if self.server:
            self.server.terminate()
            self.server.wait(timeout=5)
            self.server_log.close()


def exercise(picker):
    p = picker
    state = p.state()
    assert state["imagePalette"] and state["backdropSource"], state
    first_color = state["imagePalette"][0]
    p.click("swatch-" + first_color)
    p.wait(lambda s:s["message"]=="Gekopieerd: "+first_color,"copy photo colour")
    deadline=time.monotonic()+3
    while not (p.base/"clipboard.txt").exists() and time.monotonic()<deadline:time.sleep(.02)
    assert (p.base/"clipboard.txt").read_text()==first_color
    p.click("backdrop-toggle")
    assert not p.state()["backdrop"]
    p.click("backdrop-toggle")
    assert p.state()["backdrop"]
    p.click("local-colour-0")
    p.wait(lambda s: 0 < s["count"] < 48 and s["filter"] == 0, "local colour filter")
    p.click("local-colour-all")
    p.wait(lambda s: s["count"] == 48, "clear colour filter")
    p.ipc("harness", "key", 0x46)  # F: favorite, deliberately delayed worker.
    assert p.state()["chosenFavorite"]
    p.click("source-wallhaven")
    p.click("source-local")
    p.wait(lambda s: s["source"] == "local" and not s["loading"], "source switch waits for pending preference write")
    assert p.state()["chosenFavorite"], "catalog replaced favorite with old disk state"
    for mode in ["slices", "mosaic", "coverflow", "orbit", "hex"]:
        p.click("mode-" + mode)
        p.wait(lambda s: s["mode"] == mode and not s["motion"].get("moving"), mode)
        p.wheel(p.state(), -120)
        p.wait(lambda s: not s["motion"]["moving"] and abs(s["motion"]["contentX"] - s["motion"]["targetX"]) < .5, mode + " settles")
    p.ipc("picker", "trace", "true")
    for _ in range(8):
        p.wheel(p.state(), -120)
        time.sleep(.04)
    p.wait(lambda s: not s["motion"]["moving"], "wheel burst settles")
    time.sleep(.5)
    samples = json.loads(p.ipc("picker", "samples"))
    p.ipc("picker", "trace", "false")
    assert len(samples) > 10, "no animation frames recorded"
    assert all(b["x"] >= a["x"] - .2 for a, b in zip(samples, samples[1:])), "wheel reversed after input/idle"
    frames = sorted(sample["dt"] for sample in samples)
    (p.base / "scroll-metrics.json").write_text(json.dumps(dict(frames=len(frames), medianMs=frames[len(frames)//2],
                                                             p95Ms=frames[int(len(frames)*.95)], maxMs=max(frames), backwardSteps=0), indent=2))
    p.click("backdrop-toggle")
    time.sleep(.3)
    p.capture("hexagons")  # Verify card shaders without the photo layer behind them.
    p.click("backdrop-toggle")
    p.picture()
    applied = p.wait(lambda s: s["message"] == "Wallpaper ingesteld", "one click applies local image")
    assert (p.base / "applied.log").read_text() == applied["current"]
    p.click("source-wallhaven")
    p.wait(lambda s: s["source"] == "wallhaven" and s["count"] >= 24 and not s["loading"], "Wallhaven initial search")
    exercise_filters(p)
    before = p.state()["motion"]["contentX"]
    for _ in range(7):
        p.wheel(p.state(), -120)
    state = p.wait(lambda s: s["page"] >= 2 and not s["loading"] and not s["motion"]["moving"], "automatic next page")
    assert state["motion"]["contentX"] > before
    chosen, camera = state["chosenId"], state["motion"]["contentX"]
    time.sleep(.6)
    assert abs(p.state()["motion"]["contentX"] - camera) < .5, "append/idle reset camera"
    p.tile_action()
    downloaded=p.wait(lambda s:bool(s["chosenPath"]) and not s["busy"],"hover download saves without opening preview")
    assert not downloaded["preview"]
    downloaded_path=Path(downloaded["chosenPath"])
    assert downloaded_path.is_file()
    p.tile_action("remove")
    removed=p.wait(lambda s:not s["chosenPath"] and not s["busy"],"hover remove updates downloaded state")
    assert not removed["preview"] and not downloaded_path.exists()
    (p.base / "fail-next-preview").touch()
    p.picture()
    p.wait(lambda s: s["preview"] and "Previewtest" in s["previewMessage"] and not s["previewLoading"], "preview network error")
    p.click("preview-retry")
    state = p.wait(lambda s: s["preview"] and s["previewInfo"].get("id") == chosen, "preview retry opens correct full image")
    p.capture("preview")
    p.click("preview-zoom-in")
    assert p.state()["previewZoom"] > 1
    start = p.state()["previewPan"]
    p.ipc("harness", "drag", 950, 500, -160, -100)
    end = p.state()["previewPan"]
    assert end["x"] > start["x"] or end["y"] > start["y"], "zoomed image cannot be dragged"
    p.click("preview-zoom-reset")
    assert p.state()["previewZoom"] == 1
    p.click("preview-next")
    p.click("preview-next")
    p.click("preview-next")
    state = p.wait(lambda s: s["chosenId"] != chosen and s["previewInfo"].get("id") == s["chosenId"], "preview next loads correct image")
    chosen = state["chosenId"]
    p.click("preview-download")
    state = p.wait(lambda s: bool(s.get("chosenPath")) and not s["busy"], "preview download")
    assert state["chosenId"] == chosen, "download changed selected identity"
    assert state["previewMessage"] == "Opgeslagen in je wallpapercollectie"
    p.click("preview-apply")
    p.wait(lambda s: s["previewMessage"] == "Wallpaper ingesteld", "preview apply reports result")
    # Direct apply must download first, even when only a preview was opened.
    p.click("preview-next")
    state=p.wait(lambda s: s["previewInfo"].get("id")==s["chosenId"],"next full image")
    assert not state["chosenPath"]
    assert "/full/" in state["previewSource"], "preview used a thumbnail"
    p.click("preview-apply")
    state=p.wait(lambda s: s["previewMessage"]=="Wallpaper ingesteld" and not s["busy"],"direct apply downloads and applies")
    assert Path(state["current"]).parent==p.base/"library",state
    assert Path(state["current"]+".json").is_file(),"download lost tags sidecar"
    # Applying before HD is ready must use the pending transfer, even after
    # closing the preview. It must neither download twice nor abandon the apply.
    (p.base / "slow-next-preview").touch()
    (p.base / "expect-preview-before-save").touch()
    p.click("preview-next")
    p.click("preview-apply")
    assert p.state()["busy"]
    p.click("preview-close")
    state=p.wait(lambda s:s["message"]=="Wallpaper ingesteld" and not s["busy"],"apply waits for pending HD while preview is closed")
    assert not state["preview"]
    (p.base / "expect-preview-before-save").unlink()
    p.picture()
    p.wait(lambda s:s["preview"] and bool(s["previewInfo"].get("id")),"reopen after queued apply")
    p.ipc("harness", "key", 0x01000000)  # Escape
    p.wait(lambda s: not s["preview"], "Escape returns to browsing")
    p.click("remote-colour-0066cc")
    p.wait(lambda s: s["remoteColor"] == "0066cc" and "0066cc" in s["chosen"] and not s["loading"], "remote colour triggers search")
    p.ipc("harness", "text", "fout")
    p.wait(lambda s: "Testverbinding" in s["message"] and not s["loading"], "network error visible")
    p.click("remote-retry")
    p.wait(lambda s: "fout" in s["chosen"] and not s["loading"] and not s["message"], "network error retry")
    p.ipc("harness", "text", "traag")
    time.sleep(.5)
    p.ipc("harness", "text", "nieuw")
    p.wait(lambda s: "nieuw" in s["chosen"] and not s["loading"], "latest search wins")
    time.sleep(.8)
    assert "nieuw" in p.state()["chosen"], "stale query overwrote new results"
    p.click("mode-wall")
    p.wait(lambda s: s["mode"] == "wall", "grid")
    before = p.state()["motion"]["contentY"]
    row = p.state()["motion"]["rowHeight"]
    p.wheel(p.state(), -120)
    state=p.wait(lambda s:not s["motion"]["moving"], "grid row wheel settles")
    assert abs(state["motion"]["contentY"] - before - row) < 1, state["motion"]
    for _ in range(3): p.wheel(p.state(), -120)
    state=p.wait(lambda s:not s["motion"]["moving"], "grid burst settles")
    position=state["motion"]["contentY"]
    time.sleep(.5)
    assert abs(p.state()["motion"]["contentY"] - position) < .5, "grid scroll moved after idle"
    p.capture("grid")
    p.picture()
    p.wait(lambda s: s["preview"] and bool(s["previewInfo"].get("id")), "grid click opens preview")
    # Both side margins must close without closing the picker itself.
    for side in ["left", "right"]:
        image=json.loads(p.ipc("harness","previewGeometry"))
        assert image["paintedWidth"] < image["width"]-10,image
        x=image["x"]+(5 if side=="left" else image["width"]-5)
        p.ipc("harness","click",round(x),round(image["y"]+image["height"]/2))
        p.wait(lambda s:not s["preview"],side+" margin closes preview")
        p.picture()
        p.wait(lambda s:s["preview"] and bool(s["previewInfo"].get("id")),"reopen after "+side)
    p.click("preview-close")
    p.click("mode-coverflow")
    p.wait(lambda s:s["mode"]=="coverflow" and not s["motion"].get("moving"),"coverflow")
    p.capture("coverflow")
    p.tile_action("apply")
    state=p.wait(lambda s:s["message"]=="Wallpaper ingesteld" and not s["busy"],"tile apply downloads and sets")
    assert not state["preview"]
    assert Path(state["current"]).parent==p.base/"library"
    p.click("source-nasa")
    state=p.wait(lambda s:s["source"]=="nasa" and s.get("chosenId", "").startswith("nasa-") and not s["loading"],"NASA source")
    p.ipc("harness","topic",3)
    p.wait(lambda s:"earth" in s["chosen"] and not s["loading"],"NASA topic filter")
    p.picture()
    p.wait(lambda s:s["preview"] and s["previewInfo"].get("id")==s["chosenId"],"NASA preview")
    p.click("preview-apply")
    state=p.wait(lambda s:s["previewMessage"]=="Wallpaper ingesteld" and not s["busy"],"NASA apply")
    assert Path(state["current"]).name.startswith("nasa-")
    assert json.loads(Path(state["current"]+".json").read_text())["source"]=="nasa"
    p.click("preview-close")
    p.click("source-commons")
    state=p.wait(lambda s:s["source"]=="commons" and s.get("chosenId","").startswith("commons-") and not s["loading"],"Commons source")
    p.click("tag-landscape")
    p.wait(lambda s:"landscape" in s.get("chosen","") and not s["loading"],"tag click searches source")
    p.click("mode-orbit")
    p.wait(lambda s:s["mode"]=="orbit" and not s["motion"].get("moving"),"Orbit")
    p.capture("orbit")
    assert p.state()["imagePalette"] and p.state()["tags"]
    p.picture()
    p.wait(lambda s:s["preview"] and s["previewInfo"].get("id")==s.get("chosenId"),"Commons full preview")
    p.click("preview-apply")
    state=p.wait(lambda s:s["previewMessage"]=="Wallpaper ingesteld" and not s["busy"],"Commons apply")
    assert Path(state["current"]).name.startswith("commons-")
    assert json.loads(Path(state["current"]+".json").read_text())["license"]=="CC BY 4.0"
    p.click("preview-close")
    p.click("source-wallhaven")
    p.wait(lambda s:s["source"]=="wallhaven" and s["count"]>0 and not s["loading"],"return to Wallhaven")
    p.ipc("harness","topic",1)
    p.wait(lambda s:"nature" in s["chosen"] and not s["loading"],"Wallhaven tag topic")
    p.ipc("harness", "resize", 1280, 720)
    time.sleep(.3)
    p.capture("compact")
    p.click("source-local")
    p.wait(lambda s: s["source"] == "local" and not s["loading"], "return to local library")
    p.click("mode-hex")
    p.ipc("harness", "resize", 1024, 768)
    time.sleep(.4)
    p.capture("compact-hexagons")
    exercise_sources(p)
    # No warnings about QML exceptions, invalid shader bindings or test reloads.
    log = (p.base / "quickshell.log").read_text()
    for error in ["ReferenceError", "TypeError", "Binding loop", "Failed to create", "ERROR:"]:
        assert error not in log, log
    print("ok: full UI clicks, all layouts, wheel, append, filters, preview, zoom, download/apply, Escape, errors/retry and search races")


def exercise_sources(p):
    assert 'pexels' not in p.state()['availableSources'], 'Pexels shown without a key'
    assert 'zedge' not in p.state()['availableSources'], 'Removed Zedge source is still shown'
    # Keys travel through a real masked field and stdin into isolated storage.
    p.click("sources-settings")
    p.wait(lambda s:s["credentialsOpen"], "key settings")
    p.capture("api-settings-compact")
    for source in ["wallhaven", "wallpaperscom", "pixabay", "pexels"]:
        secret="test-private-" + source + "-123456"
        p.ipc("harness", "keyText", "key-" + source, secret)
        p.click("save-key-" + source)
        p.wait(lambda s:any(v["id"]==source and v["configured"] for v in s["credentials"]), "key saved " + source)
        assert secret not in json.dumps(p.state())
    keys=p.base/"config/kingstra/wallpaper-sources.json"
    assert keys.stat().st_mode & 0o777 == 0o600
    assert set(json.loads(keys.read_text()))=={"wallhaven","wallpaperscom","pixabay","pexels"}
    p.click("sources-close")
    p.click("source-pexels")
    p.wait(lambda s:s['source']=='pexels' and s['count']>0 and not s['loading'], 'configured Pexels is available')
    p.click("sources-settings")
    p.click("remove-key-pexels")
    p.wait(lambda s:any(v["id"]=="pexels" and not v["configured"] for v in s["credentials"]), "remove key")
    assert p.state()['source']=='local' and 'pexels' not in p.state()['availableSources'], 'removing the active key left a hidden source selected'
    p.ipc("harness", "keyText", "key-pexels", "test-private-pexels-123456")
    p.click("save-key-pexels")
    p.wait(lambda s:'pexels' in s['availableSources'] and s["credentialMessage"], "key unlocks source")
    p.click("sources-close")
    for source in ["wallpaperscom","alphacoders","backiee","wallpaperscraft","goodfon","wallpaperswide","pexels","pixabay"]:
        p.click("source-"+source)
        p.wait(lambda s:s["source"]==source and s.get("chosenId", "").startswith(source+"-") and not s["loading"], "source " + source)
        p.picture()
        p.wait(lambda s:s["preview"] and s["previewInfo"].get("id")==s["chosenId"], "preview " + source)
        p.click("preview-apply")
        state=p.wait(lambda s:s["previewMessage"]=="Wallpaper ingesteld" and not s["busy"], "save/apply " + source)
        assert Path(state["current"]).name.startswith(source+"-")
        metadata=json.loads(Path(state["current"]+".json").read_text())
        assert metadata["source"]==source and metadata["tag_names"]
        p.click("preview-close")
    assert "test-private-" not in (p.base/"quickshell.log").read_text()
    p.click("pixabay-safe")
    p.wait(lambda s:not s["safeSearch"] and not s["loading"], "Pixabay safe search checkbox off")
    p.ipc("harness", "combo", "pixabay-category", 3)
    p.ipc("harness", "combo", "remote-sort", 1)
    p.click("remote-colour-all")
    p.click("remote-colour-0066cc")
    p.ipc("harness", "keyText", "remote-resolution", "2560x1440")
    p.ipc("harness", "text", "pixabay-filter-contract")
    p.wait(lambda s:"pixabay-filter-contract" in s.get("chosen","") and not s["loading"], "Pixabay filters delivered")
    searches=[json.loads(line) for line in (p.base/"searches.jsonl").read_text().splitlines()]
    query=next(row for row in reversed(searches) if row.get("--query")=="pixabay-filter-contract")
    assert query["--purity"]=="111" and query["--category"]=="nature" and query["--atleast"]=="2560x1440" and query["--color"]=="0066cc",query
    p.click("pixabay-safe")
    p.wait(lambda s:s["safeSearch"] and not s["loading"], "Pixabay safe search checkbox on")
    p.capture("pixabay-filters")
    p.click("source-hdqwalls")
    state=p.wait(lambda s:s['externalSource'] and not s['loading'] and s['count']==0, 'honest HDQwalls external fallback')
    assert 'browsercontrole' in state['notice']
    p.capture('hdqwalls-external')
    print("ok: API fields, masked secrets, Pexels hidden/unlocked/removed, eight sources preview/save/apply and HDQwalls external fallback")


def exercise_filters(p):
    assert p.state()["purity"]=="100" and p.state()["safeSearch"]
    for name,expected in [("purity-2","101"),("purity-0","001"),("purity-1","011"),("purity-2","010")]:
        p.click(name)
        p.wait(lambda s:s["purity"]==expected and not s["loading"], "independent purity " + expected)
        time.sleep(.5)
        rows=[json.loads(line) for line in (p.base/"searches.jsonl").read_text().splitlines()]
        assert rows[-1]["--purity"]==expected,rows[-1]
    p.click("purity-1")
    p.wait(lambda s:s["purity"]=="000" and not s["count"] and "Vink" in s["message"], "no purity selected")
    p.click("purity-0")
    p.wait(lambda s:s["purity"]=="100" and s["count"]>=24 and not s["loading"], "restore SFW only")
    p.click("exclude-ai")
    p.wait(lambda s:s["excludeAi"] and not s["loading"], "no AI option")
    time.sleep(.7)
    rows=[json.loads(line) for line in (p.base/"searches.jsonl").read_text().splitlines()]
    assert rows[-1]["--exclude-ai"], rows[-1]
    p.capture("wallhaven-filter-checkboxes")
    p.click("exclude-ai")
    p.wait(lambda s:not s["excludeAi"] and s["count"]>=24 and not s["loading"], "restore AI filter")
    print("ok: independent SFW/Sketchy/NSFW checkboxes, empty selection, SFW default and no AI search flag")


def exercise_paging(p):
    for mode in ["wall","slices","hex","mosaic","coverflow","orbit"]:
        p.click("mode-"+mode)
        p.ipc("picker","browse","paging-"+mode)
        state=p.wait(lambda s:s["count"]>=24 and not s["loading"],"initial "+mode+" results")
        time.sleep(.4)
        state=p.wait(lambda s:not s["loading"],"initial prefetch "+mode)
        page=state["page"]
        key="contentY" if mode=="wall" else "contentX"
        initial=state["motion"][key]
        before=None
        for _ in range(65):
            state=p.state()
            if state["loading"] and state["page"]==page:
                before=state;break
            if state["page"]>page:raise AssertionError("paging fixture returned before position snapshot")
            p.wheel(state,-120)
            time.sleep(.03)
        assert before is not None,"no next page requested for "+mode
        after=p.wait(lambda s:s["page"]>page and not s["loading"] and not s["motion"].get("moving",False),"append "+mode)
        assert after["motion"][key]>=before["motion"][key]-.5,(mode,before,after)
        assert after["motion"][key]>initial,(mode,initial,after)
        assert after["selected"]>=before["selected"],(mode,before,after)
        print("ok: "+mode+" page appended without losing position",flush=True)


def exercise_live(p):
    p.click("source-wallhaven")
    p.ipc("harness", "text", "landscape")
    time.sleep(.7)
    p.wait(lambda s: s["count"] >= 24 and not s["loading"], "real Wallhaven search", timeout=55)
    p.click("remote-colour-0066cc")
    time.sleep(.7)
    state = p.wait(lambda s: s["remoteColor"] == "0066cc" and s["count"] > 0 and not s["loading"], "real Wallhaven colour search", timeout=55)
    p.capture("wallhaven-live")
    p.picture()
    state = p.wait(lambda s: s["preview"] and s["previewInfo"].get("id") == s["chosenId"] and not s["previewLoading"], "real full resolution Wallhaven preview", timeout=55)
    with Image.open(state["previewInfo"]["path"]) as image:
        assert image.width > 768 or image.height > 480, "preview is only a thumbnail"
    p.capture("wallhaven-live-preview")
    started=time.monotonic()
    p.click("preview-download")
    state=p.wait(lambda s:bool(s.get("chosenPath")) and not s["busy"],"save actual cached Wallhaven preview",timeout=20)
    elapsed=time.monotonic()-started
    record=json.loads(Path(state["chosenPath"]+".json").read_text())
    assert record["source"]=="wallhaven" and record["tag_names"]
    (p.base / "live-result.json").write_text(json.dumps(dict(state=state,saveSeconds=elapsed,metadata=record), indent=2))
    print("ok: cached Wallhaven save with tags",round(elapsed,3),"s")
    print("ok: actual Wallhaven search, colour filtering and full resolution preview")


def exercise_live_nasa(p):
    p.click("source-nasa")
    state=p.wait(lambda s:s["source"]=="nasa" and s["count"]>0 and not s["loading"],"actual NASA search",timeout=55)
    p.click("mode-coverflow")
    time.sleep(.3)
    p.capture("nasa-live-coverflow")
    p.picture()
    state=p.wait(lambda s:s["previewInfo"].get("id")==s.get("chosenId") and not s["previewLoading"] and bool(s["previewSource"]),"actual NASA HD preview",timeout=55)
    p.capture("nasa-live-preview")
    with Image.open(state["previewInfo"]["path"]) as image:
        assert image.width>768 or image.height>480
    started=time.monotonic()
    p.click("preview-download")
    state=p.wait(lambda s:bool(s.get("chosenPath")) and not s["busy"],"save cached NASA full image",timeout=20)
    elapsed=time.monotonic()-started
    record=json.loads(Path(state["chosenPath"]+".json").read_text())
    assert record["source"]=="nasa" and record["uploader"]
    (p.base/"live-result.json").write_text(json.dumps(dict(state=state,saveSeconds=elapsed,metadata=record),indent=2))
    print("ok: actual NASA search, HD preview and cached save with attribution",round(elapsed,3),"s")


def exercise_live_commons(p):
    p.click("source-commons")
    p.ipc("harness", "text", "mountain")
    state=p.wait(lambda s:s["source"]=="commons" and s["count"]>0 and not s["loading"],"actual Commons search",timeout=70)
    p.click("mode-orbit")
    time.sleep(.5)
    p.capture("commons-live-orbit")
    assert state["imagePalette"] and state["tags"],state
    p.picture()
    state=p.wait(lambda s:s["previewInfo"].get("id")==s.get("chosenId") and bool(s["previewSource"]),"actual Commons full preview",timeout=60)
    p.capture("commons-live-preview")
    p.click("preview-download")
    state=p.wait(lambda s:bool(s.get("chosenPath")) and not s["busy"],"save Commons image",timeout=20)
    record=json.loads(Path(state["chosenPath"]+".json").read_text())
    assert record["source"]=="commons" and record["license"] and record["uploader"]
    (p.base/"live-result.json").write_text(json.dumps(dict(state=state,metadata=record),indent=2))
    print("ok: actual Commons API, photo palette, tags, HD preview, save, author and license")


def exercise_live_source(p, source):
    p.click('source-'+source)
    p.ipc('harness','text','nature')
    state=p.wait(lambda s:s['source']==source and s['count']>0 and not s['loading'], 'actual '+source+' search', timeout=70)
    p.click('mode-wall')
    time.sleep(.4)
    p.capture(source+'-live-grid')
    p.picture()
    p.wait(lambda s:s['preview'] and s['previewInfo'].get('id')==s.get('chosenId') and bool(s['previewSource']), 'actual '+source+' HD preview', timeout=60)
    p.capture(source+'-live-preview')
    p.click('preview-download')
    state=p.wait(lambda s:bool(s.get('chosenPath')) and not s['busy'], 'save '+source+' image', timeout=20)
    path=Path(state['chosenPath'])
    record=json.loads(Path(str(path)+'.json').read_text())
    assert path.parent==p.base/'library' and record['source']==source and record['tag_names'] and record['uploader'],record
    with Image.open(path) as image:
        assert image.width>=1920 and image.height>=1080, image.size
    (p.base/'live-result.json').write_text(json.dumps(dict(state=state,metadata=record),indent=2))
    print('ok: actual '+source+' search, native HD preview, download, tags and credit')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="Keep screenshots, logs and isolated fixtures in this new directory")
    parser.add_argument("--xvfb", type=Path, default=shutil.which("Xvfb"), help="Xvfb binary for shader/image verification; detected automatically if installed")
    parser.add_argument("--live-wallhaven", action="store_true", help="Use actual Wallhaven search/preview instead of deterministic remote fixtures; never applies to the desktop")
    parser.add_argument("--live-commons", action="store_true", help="Check real Commons search, metadata, HD preview and save in private files")
    parser.add_argument("--live-nasa", action="store_true", help="Exercise the actual NASA API with all files kept in the private test directory")
    parser.add_argument("--live-source", choices=['goodfon','wallpaperswide'], help="Exercise a new website source with real Qt input, HD preview and private download")
    parser.add_argument("--paging-only", action="store_true", help="Check real wheel pagination in all four views")
    args = parser.parse_args()
    temp = None
    if args.output:
        args.output.mkdir(parents=True, exist_ok=False)
        base = args.output.resolve()
    else:
        temp = tempfile.TemporaryDirectory(prefix="kingstra-picker-test-")
        base = Path(temp.name)
    picker = None
    try:
        picker = Picker(base, args.xvfb, args.live_wallhaven or args.live_nasa or args.live_commons or bool(args.live_source))
        if args.live_source:
            exercise_live_source(picker,args.live_source)
        elif args.live_commons:
            exercise_live_commons(picker)
        elif args.live_nasa:
            exercise_live_nasa(picker)
        elif args.live_wallhaven:
            exercise_live(picker)
        elif args.paging_only:
            exercise_paging(picker)
        else:
            exercise(picker)
        print("ok: real shader images present" if picker.rendered else "Shader images not checked: run with --xvfb /path/to/Xvfb")
    finally:
        if picker:
            picker.close()
        if temp:
            temp.cleanup()
    if args.output:
        print(f"Evidence: {base}")


if __name__ == "__main__":
    main()
