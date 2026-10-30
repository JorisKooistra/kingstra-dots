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
            (farm / entry.name).symlink_to(entry)
    wallpaper = farm / "wallpaper"
    wallpaper.mkdir()
    for entry in (SOURCE / "wallpaper").iterdir():
        if entry.name not in {"PickerWindow.qml", "backend.py"}:
            (wallpaper / entry.name).symlink_to(entry)
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
    palette = base / "config/kingstra/state/matugen-palette.json"
    palette.parent.mkdir(parents=True)
    palette.write_text("{}")
    runtime = base / "runtime"
    runtime.mkdir(mode=0o700)
    env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), XDG_CONFIG_HOME=str(base / "config"),
               XDG_CACHE_HOME=str(base / "cache"), KINGSTRA_WALLPAPER_DIR=str(library),
               KINGSTRA_PICKER_TEST_DIR=str(base), QT_QPA_PLATFORM="offscreen", QSG_RHI_BACKEND="opengl",
               QT_QPA_OFFSCREEN_NO_GLX="1", LIBGL_ALWAYS_SOFTWARE="1")
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
            ready = select.select([read_fd], [], [], 8)[0]
            display = os.read(read_fd, 64).decode().strip() if ready else ""
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

    def tile_action(self):
        state=self.state()
        v,point=state["viewport"],state["motion"]["selectionPoint"]
        if state["mode"]=="hex":height=state["motion"]["hexHeight"]
        elif state["mode"]=="wall":height=v["width"]/state["motion"]["columns"]*.62-12
        else:raise AssertionError("action geometry fixture expects hex or grid")
        x,y=round(v["x"]+point["x"]),round(v["y"]+point["y"]-height/2+27)
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
    for mode in ["slices", "mosaic", "hex"]:
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
    p.capture("hexagons")
    p.picture()
    applied = p.wait(lambda s: s["message"] == "Wallpaper ingesteld", "one click applies local image")
    assert (p.base / "applied.log").read_text() == applied["current"]
    p.click("source-wallhaven")
    p.wait(lambda s: s["source"] == "wallhaven" and s["count"] >= 24 and not s["loading"], "Wallhaven initial search")
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
    p.tile_action()
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
    p.capture("grid")
    p.picture()
    p.wait(lambda s: s["preview"] and bool(s["previewInfo"].get("id")), "grid click opens preview")
    p.click("preview-close")
    p.ipc("harness", "resize", 1280, 720)
    time.sleep(.3)
    p.capture("compact")
    p.click("source-local")
    p.wait(lambda s: s["source"] == "local" and not s["loading"], "return to local library")
    p.click("mode-hex")
    p.ipc("harness", "resize", 1024, 768)
    time.sleep(.4)
    p.capture("compact-hexagons")
    # No warnings about QML exceptions, invalid shader bindings or test reloads.
    log = (p.base / "quickshell.log").read_text()
    for error in ["ReferenceError", "TypeError", "Binding loop", "Failed to create", "ERROR:"]:
        assert error not in log, log
    print("ok: full UI clicks, all layouts, wheel, append, filters, preview, zoom, download/apply, Escape, errors/retry and search races")


def exercise_paging(p):
    for mode in ["wall","slices","hex","mosaic"]:
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
    (p.base / "live-result.json").write_text(json.dumps(state, indent=2))
    print("ok: actual Wallhaven search, colour filtering and full resolution preview")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="Keep screenshots, logs and isolated fixtures in this new directory")
    parser.add_argument("--xvfb", type=Path, default=shutil.which("Xvfb"), help="Xvfb binary for shader/image verification; detected automatically if installed")
    parser.add_argument("--live-wallhaven", action="store_true", help="Use actual Wallhaven search/preview instead of deterministic remote fixtures; never applies to the desktop")
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
        picker = Picker(base, args.xvfb, args.live_wallhaven)
        if args.live_wallhaven:
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
