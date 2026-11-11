"""Videowallpapers normaliseren: niet groter, sneller of zwaarder dan nodig.

mpvpaper speelt een video op elk scherm apart af, dus een 4K-clip op drie
1080p-schermen kost drie 4K-decodes voor niets. Bij opslaan (en via de
mapbewaker voor wat je zelf neerzet) zetten we een video daarom om naar de
ingestelde maat:

  videoHeight  "auto" (grootste scherm in gebruik, standaard) | "1080" |
               "1440" | "2160" | "0" (origineel laten)
  videoFps     "30" (standaard) | "60" | "0" (origineel laten)

in ~/.config/kingstra/wallpaper-picker.json. Alleen wat erboven zit wordt
omgezet; kleiner wordt niets. Het origineel gaat naar de prullenbak (terug
te halen), de sidecar verhuist mee en krijgt `normalized` zodat een bestand
maar één keer wordt bekeken.
"""
import contextlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

HEIGHTS = {"auto", "1080", "1440", "2160", "0"}
FPS = {"30", "60", "0"}
# Ruim voldoende voor stilstaande natuur/anime-loops op 1080p; schaalt mee
# met het aantal pixels.
BITRATE_1080 = 8000
WORK = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "kingstra/video-normalize"


def monitor_height():
    """Hoogste scherm in gebruik, in echte pixels (gedraaid telt de breedte)."""
    with contextlib.suppress(OSError, subprocess.SubprocessError, ValueError, TypeError):
        result = subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True, timeout=5)
        heights = []
        for monitor in json.loads(result.stdout or "[]"):
            width, height = int(monitor.get("width", 0)), int(monitor.get("height", 0))
            heights.append(width if int(monitor.get("transform", 0)) % 2 else height)
        if heights and max(heights) > 0: return max(heights)
    return 1080


def target(settings):
    """(hoogte of 0, fps of 0) volgens de instellingen."""
    height = str(settings.get("videoHeight", "auto"))
    fps = str(settings.get("videoFps", "30"))
    height = height if height in HEIGHTS else "auto"
    fps = fps if fps in FPS else "30"
    return (monitor_height() if height == "auto" else int(height)), int(fps)


def signature(height, fps):
    return f"h{height}f{fps}"


def probe(path):
    result = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                             "stream=codec_name,pix_fmt,width,height,avg_frame_rate,r_frame_rate,bit_rate:format=bit_rate,duration",
                             "-of", "json", str(path)], capture_output=True, text=True, timeout=30)
    data = json.loads(result.stdout or "{}")
    stream = (data.get("streams") or [{}])[0]
    fmt = data.get("format") or {}

    def rate(value):
        with contextlib.suppress(ValueError, ZeroDivisionError):
            top, _, bottom = str(value).partition("/")
            return float(top) / float(bottom or 1)
        return 0.0

    def number(value):
        with contextlib.suppress(TypeError, ValueError): return float(value)
        return 0.0

    return dict(codec=stream.get("codec_name", ""), pix_fmt=stream.get("pix_fmt", ""),
                width=int(stream.get("width") or 0), height=int(stream.get("height") or 0),
                fps=rate(stream.get("avg_frame_rate")) or rate(stream.get("r_frame_rate")),
                kbps=(number(stream.get("bit_rate")) or number(fmt.get("bit_rate"))) / 1000,
                duration=number(fmt.get("duration")))


def reasons(info, height, fps):
    """Waarom deze video omgezet moet worden; leeg = laten zoals hij is."""
    if not height and not fps: return []
    found = []
    # Liggend: de korte kant is de hoogte. Staand materiaal net zo.
    short = min(info["width"], info["height"]) or info["height"]
    if height and short > height + 8: found.append(f"{short}p → {height}p")
    if fps and info["fps"] > fps + 0.5: found.append(f"{round(info['fps'])} → {fps} fps")
    if info["codec"] != "h264": found.append(f"{info['codec'] or '?'} → h264")
    elif info["pix_fmt"] not in {"yuv420p", "yuvj420p"}: found.append(f"{info['pix_fmt']} → 8-bit")
    cap = bitrate_cap(height or short)
    if info["kbps"] > cap * 1.25: found.append(f"{round(info['kbps'] / 1000, 1)} → ≤{round(cap / 1000)} Mb/s")
    return found


def bitrate_cap(height):
    return round(BITRATE_1080 * max(1.0, (height / 1080) ** 2))


def convert(source, height, fps, info, progress=None):
    """Zet `source` om naar een tijdelijke mp4 naast het bestand; geeft dat pad."""
    filters = []
    short = min(info["width"], info["height"]) or info["height"]
    if height and short > height + 8:
        # Korte kant naar `height`, lange kant even getal; aspect blijft gelijk.
        filters.append(f"scale='if(gt(iw,ih),-2,{height})':'if(gt(iw,ih),{height},-2)':flags=lanczos")
    if fps and info["fps"] > fps + 0.5: filters.append(f"fps={fps}")
    filters.append("format=yuv420p")
    cap = bitrate_cap(height or short)
    # Buiten de wallpapermap werken: anders ziet skwd een half bestand (thumb
    # FAILED om de 2 s) en start de mapbewaker steeds opnieuw.
    WORK.mkdir(parents=True, exist_ok=True)
    fd, temp = tempfile.mkstemp(dir=WORK, prefix="norm-", suffix=".mp4")
    os.close(fd)
    command = ["ffmpeg", "-nostdin", "-v", "error", "-y", "-i", str(source), "-an", "-sn", "-dn",
               "-map", "0:v:0", "-vf", ",".join(filters), "-c:v", "libx264", "-preset", "medium", "-crf", "20",
               "-maxrate", f"{cap}k", "-bufsize", f"{cap * 2}k", "-profile:v", "high",
               "-movflags", "+faststart", "-progress", "pipe:1", "-nostats", temp]
    try:
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                                   start_new_session=True)
        for line in process.stdout:
            key, _, value = line.strip().partition("=")
            if key == "out_time_us" and progress and info["duration"] > 0:
                with contextlib.suppress(ValueError):
                    progress(min(99, int(int(value) / 10000 / info["duration"])))
        error = process.stderr.read()
        if process.wait() or not Path(temp).stat().st_size:
            raise ValueError("Video omzetten mislukt: " + (error.strip().splitlines() or ["ffmpeg"])[-1][:160])
        return Path(temp)
    except BaseException:
        with contextlib.suppress(FileNotFoundError): os.unlink(temp)
        raise


def sidecar(path):
    return Path(str(path) + ".json")


def read_json(path):
    with contextlib.suppress(OSError, ValueError):
        data = json.loads(Path(path).read_text())
        return data if isinstance(data, dict) else {}
    return {}


def write_json(path, data):
    fd, temp = tempfile.mkstemp(dir=Path(path).parent, prefix=".picker-")
    try:
        with os.fdopen(fd, "w") as output: json.dump(data, output, ensure_ascii=False)
        os.replace(temp, path)
    finally:
        with contextlib.suppress(FileNotFoundError): os.unlink(temp)


def normalize(path, settings, progress=None, trash_original=True):
    """Geeft (pad, omgezet?, redenen). Het pad kan veranderen (.mov → .mp4)."""
    path = Path(path)
    if not shutil.which("ffmpeg") or not shutil.which("ffprobe"): return path, False, []
    height, fps = target(settings)
    marker = signature(height, fps)
    meta = read_json(sidecar(path))
    if meta.get("normalized") == marker: return path, False, []
    info = probe(path)
    # Onleesbaar of half gekopieerd (mp4 zonder index): niet aankomen.
    if not info["codec"] or not info["height"] or info["duration"] <= 0: return path, False, []
    found = reasons(info, height, fps)
    if not found:
        if meta:
            meta["normalized"] = marker
            write_json(sidecar(path), meta)
        return path, False, []
    temp = convert(path, height, fps, info, progress)
    target_path = path if path.suffix.lower() == ".mp4" else path.with_suffix(".mp4")
    if target_path != path and target_path.exists():
        for index in range(1, 100):
            candidate = path.with_name(f"{path.stem}-{index}.mp4")
            if not candidate.exists():
                target_path = candidate
                break
    old_meta = sidecar(path)
    # Origineel (met sidecar) naar de prullenbak; lukt dat niet, dan laten we
    # alles staan en gooien de omzetting weg.
    if trash_original:
        gio = shutil.which("gio")
        files = [str(path)] + ([str(old_meta)] if old_meta.is_file() else [])
        if not gio or subprocess.run([gio, "trash", *files], capture_output=True).returncode:
            with contextlib.suppress(FileNotFoundError): os.unlink(temp)
            raise ValueError("Origineel kon niet naar de prullenbak; niets gewijzigd")
    os.chmod(temp, 0o644)
    shutil.move(str(temp), str(target_path))
    if meta or not trash_original:
        meta = dict(meta, path=str(target_path), normalized=marker,
                    normalized_from=dict(width=info["width"], height=info["height"], fps=round(info["fps"], 2),
                                         codec=info["codec"], kbps=round(info["kbps"])))
        write_json(sidecar(target_path), meta)
    return target_path, True, found


def playable_preview(path):
    """Voorbeeldclip die de kiezer zeker kan afspelen. MoeWalls levert AV1;
    Qt probeert dat via de GPU en valt op kaarten zonder AV1 niet terug op
    software. Niet-h264 wordt daarom eenmalig een kleine h264-mp4 (±2 s)."""
    path = Path(path)
    if not shutil.which("ffmpeg") or not shutil.which("ffprobe"): return path
    target = path.with_name(path.stem + ".h264.mp4")
    if target.is_file() and target.stat().st_size: return target
    with contextlib.suppress(Exception):
        if probe(path)["codec"] == "h264": return path
    fd, temp = tempfile.mkstemp(dir=path.parent, prefix=".prev-", suffix=".mp4")
    os.close(fd)
    try:
        result = subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-y", "-i", str(path), "-an", "-sn",
                                 "-vf", "scale='min(1280,iw)':-2,format=yuv420p", "-c:v", "libx264", "-preset", "veryfast",
                                 "-crf", "26", "-movflags", "+faststart", temp], capture_output=True, timeout=120)
        if result.returncode or not Path(temp).stat().st_size: return path
        os.replace(temp, target)
        return target
    finally:
        with contextlib.suppress(FileNotFoundError): os.unlink(temp)
