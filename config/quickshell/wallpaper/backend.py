#!/usr/bin/env python3
"""Kingstra picker worker. JSON lines out; no dependency on skwd's UI/indexer.

Only `apply` changes the wallpaper. All expensive decoding/network work runs
outside the QML thread. Cache keys include source mtime and size.
"""
import argparse
import concurrent.futures
import contextlib
import colorsys
import datetime
import fcntl
import hashlib
import html
from html.parser import HTMLParser
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

HOME = Path.home()
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config"))
CACHE = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "kingstra/wallpaper-picker"
SETTINGS = CONFIG / "kingstra/wallpaper-picker.json"
IMAGES = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".gif", ".avif"}
VIDEOS = {".mp4", ".webm", ".mkv", ".mov"}


def read_json(path, fallback=None):
    try:
        return json.loads(Path(path).read_text())
    except (OSError, ValueError):
        return {} if fallback is None else fallback


def emit(kind, **data):
    print(json.dumps(dict(event=kind, **data), ensure_ascii=False), flush=True)


def atomic_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp = tempfile.mkstemp(dir=path.parent, prefix=".picker-")
    try:
        with os.fdopen(fd, "w") as output:
            json.dump(data, output, ensure_ascii=False)
        os.replace(temp, path)
    finally:
        with contextlib.suppress(FileNotFoundError):
            os.unlink(temp)


def preferences(key, value):
    if key not in {"mode", "favorites", "sort", "backdrop"}:
        raise ValueError("Onbekende instelling")
    SETTINGS.parent.mkdir(parents=True, exist_ok=True)
    with SETTINGS.with_suffix(".lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        data = read_json(SETTINGS)
        if key == "favorites":
            # A toggle on a single path avoids lost updates on rapid clicks.
            favorites = set(data.get("favorites", []))
            favorites.symmetric_difference_update([value])
            data[key] = sorted(favorites)
        elif key == "mode":
            if value not in {"slices", "hex", "wall", "mosaic", "coverflow", "orbit"}:
                raise ValueError("Onbekende weergave")
            data[key] = value
        elif key == "backdrop":
            if value not in {"true", "false"}: raise ValueError("Ongeldige achtergrondinstelling")
            data[key] = value == "true"
        else:
            if value not in {"color", "date", "name"}: raise ValueError("Onbekende sortering")
            data[key] = value
        atomic_json(SETTINGS, data)
    emit("preferences", settings=data)


def skwd_config():
    # Reuse the configured library and API key, never expose the key to QML/logs.
    return read_json(CONFIG / "skwd-wall/config.json")


def library():
    configured = skwd_config().get("paths", {}).get("wallpaper", "")
    value = os.environ.get("KINGSTRA_WALLPAPER_DIR") or configured or "~/Pictures/Wallpapers"
    path = Path(value).expanduser()
    return path if path.is_absolute() else HOME / path


def current_wallpaper():
    base = CACHE.parents[1]
    for path in (base / "kingstra/theme-wallpaper-source", base / "skwd-wall/current_wallpaper",
                 base / "kingstra/last-wallpaper"):
        with contextlib.suppress(OSError):
            candidate = path.read_text().strip()
            if Path(candidate).is_file():
                # Only use the original source when a generated effect is active.
                if path.name == "theme-wallpaper-source":
                    active = base / "skwd-wall/current_wallpaper"
                    if "/theme-wallpapers/" not in active.read_text():
                        continue
                return candidate
    return ""


def thumbnail_key(path):
    stat = path.stat()
    return hashlib.sha256(f"v2:{path}:{stat.st_mtime_ns}:{stat.st_size}".encode()).hexdigest()


def color_metrics(color):
    """Same HSL hue buckets and <10% monochrome threshold as skwd v1."""
    if not re.fullmatch(r"#[0-9a-fA-F]{6}", color or ""):
        return dict(hue=99, saturation=0)
    rgb = [int(color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    hue, _, saturation = colorsys.rgb_to_hls(*rgb)
    degrees, percent = hue * 360, saturation * 100
    bucket = 99 if percent < 10 else (0 if degrees >= 340 or degrees < 25 else int((degrees - 25) // 30) + 1)
    return dict(hue=bucket, saturation=percent)


def wallhaven_id(path):
    match = re.fullmatch(r"wallhaven[-_]?([a-z0-9]{6})", Path(path).stem, re.IGNORECASE)
    return match[1].lower() if match else ""


def metadata_file(path):
    return Path(str(path) + ".json")


def local_metadata(path, index):
    record = read_json(metadata_file(path))
    if not isinstance(record, dict): record = {}
    if record.get("source") not in {"wallhaven", "nasa", "commons"}:
        identifier = wallhaven_id(path)
        record = index.get(identifier) or read_json(CACHE / "metadata" / (identifier + ".json")) if identifier else {}
        if record and not metadata_file(path).exists():
            atomic_json(metadata_file(path), dict(record, path=str(path)))
    return dict(tags=record.get("tag_names", []),
                tagAliases=[tag.get("alias", "") for tag in record.get("tags", []) if isinstance(tag, dict)],
                wallhavenId=record.get("id", "") if record.get("source") == "wallhaven" else "",
                wallhavenColors=record.get("colors", []), source=record.get("source", ""),
                sourcePage=record.get("url", ""), credit=record.get("uploader", ""),
                license=record.get("license", ""), displayName=record.get("name", ""))


def remember_wallhaven(identifier, data, path, save_sidecar=False):
    tags = [tag for tag in (data.get("tags") or []) if isinstance(tag, dict)]
    record = dict(source="wallhaven", id=identifier, path=str(path), url="https://wallhaven.cc/w/" + identifier,
                  tag_names=[tag["name"] for tag in tags if tag.get("name")], tags=tags,
                  colors=data.get("colors", []), resolution=data.get("resolution", ""),
                  purity=data.get("purity", ""), category=data.get("category", ""),
                  uploader=(data.get("uploader") or {}).get("username", ""),
                  download_url=data.get("path", ""), data=data,
                  fetched_at=datetime.datetime.now(datetime.timezone.utc).isoformat())
    atomic_json(CACHE / "metadata" / (identifier + ".json"), record)
    if save_sidecar:
        existing = read_json(metadata_file(path))
        if not isinstance(existing, dict): existing = {}
        atomic_json(metadata_file(path), dict(existing, **record))
    # Reuse the metadata already received by the preview/download API. Never
    # block the picker behind an optional background metadata request.
    with contextlib.suppress(OSError):
        lock_path = CACHE.parent / "wallhaven-tags.lock"
        lock_path.parent.mkdir(parents=True, exist_ok=True)
        with lock_path.open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            target = CONFIG / "kingstra/state/wallhaven-tags.json"
            index = read_json(target)
            index[identifier] = record
            atomic_json(target, index)
    return record


def image_details(image, target):
    """Actual sampled colours and a tiny preblurred backdrop; no theme writes."""
    from PIL import Image, ImageFilter
    sample = image.convert("RGB").resize((128, 128))
    quantized = sample.quantize(colors=32, method=Image.Quantize.MEDIANCUT)
    table = quantized.getpalette()
    candidates = sorted(quantized.getcolors(), reverse=True)
    picked = []
    for count, index in candidates:
        rgb = tuple(table[index * 3:index * 3 + 3])
        if all(sum((a - b) ** 2 for a, b in zip(rgb, other)) >= 48 ** 2 for other in picked):
            picked.append(rgb)
        if len(picked) == 8: break
    palette = ["#%02x%02x%02x" % rgb for rgb in picked]
    background = target.with_name(target.stem + ".bg.jpg")
    miniature = image.convert("RGB")
    miniature.thumbnail((320, 200))
    fd, temp = tempfile.mkstemp(dir=target.parent, prefix=".picker-", suffix=".jpg")
    try:
        with os.fdopen(fd, "wb") as output:
            miniature.filter(ImageFilter.GaussianBlur(10)).save(output, "JPEG", quality=82)
        os.replace(temp, background)
    finally:
        with contextlib.suppress(FileNotFoundError): os.unlink(temp)
    return dict(palette=palette, backdrop=background.as_uri())


def cached_visuals(target):
    data = read_json(target.with_suffix(".json"))
    result = {}
    if isinstance(data, dict) and isinstance(data.get("palette"), list):
        result["palette"] = [color for color in data["palette"] if isinstance(color, str) and re.fullmatch(r"#[0-9a-fA-F]{6}", color)]
    background = target.with_name(target.stem + ".bg.jpg")
    if background.is_file(): result["backdrop"] = background.as_uri()
    return result


def make_thumbnail(item):
    from PIL import Image, ImageOps
    path = Path(item["path"])
    target = CACHE / "thumbs" / (thumbnail_key(path) + ".jpg")
    sidecar = target.with_suffix(".json")
    metadata = read_json(sidecar)
    if target.is_file() and metadata.get("color") and metadata.get("dimensions"):
        if not metadata.get("palette") or not target.with_name(target.stem + ".bg.jpg").is_file():
            with Image.open(target) as image: metadata.update(image_details(image, target))
            atomic_json(sidecar, metadata)
        metadata.update(color_metrics(metadata["color"]))
        return dict(path=str(path), thumb=target.as_uri(), **metadata)
    target.parent.mkdir(parents=True, exist_ok=True)
    fd, temp = tempfile.mkstemp(dir=target.parent, suffix=".jpg")
    os.close(fd)
    try:
        source = path
        if item["type"] == "video":
            subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-y", "-i", str(path),
                            "-frames:v", "1", "-vf", "scale=768:480:force_original_aspect_ratio=decrease",
                            temp], timeout=25, check=True, capture_output=True)
            source = Path(temp)
        with Image.open(source) as original:
            dimensions = f"{original.width} × {original.height}"
            original.draft("RGB", (768, 480))
            image = ImageOps.exif_transpose(original)
            image.thumbnail((768, 480), Image.Resampling.LANCZOS)
            image = image.convert("RGB")
            sample = image.resize((1, 1)).getpixel((0, 0))
            color = "#%02x%02x%02x" % sample
            details = image_details(image, target)
            image.save(temp, "JPEG", quality=83)
        os.replace(temp, target)
        metadata = dict(color=color, dimensions=dimensions, **color_metrics(color), **details)
        atomic_json(sidecar, metadata)
        return dict(path=str(path), thumb=target.as_uri(), **metadata)
    finally:
        with contextlib.suppress(FileNotFoundError):
            os.unlink(temp)


def catalog():
    folder = library()
    settings = read_json(SETTINGS)
    upstream_mode = skwd_config().get("components", {}).get("wallpaperSelector", {}).get("displayMode", "hex")
    settings.setdefault("mode", upstream_mode if upstream_mode in {"hex", "slices", "wall", "mosaic", "coverflow", "orbit"} else "hex")
    settings.setdefault("backdrop", True)
    settings.setdefault("sort", "color")
    layout = skwd_config().get("components", {}).get("wallpaperSelector", {})
    settings["layout"] = {key: layout.get(key, default) for key, default in
                          dict(hexRows=2, hexCols=9, hexRadius=140, hexArc=True, hexArcIntensity=1.2,
                               hexScrollStep=1, sliceSpacing=-30).items()}
    favorites = set(settings.get("favorites", []))
    tag_index = read_json(CONFIG / "kingstra/state/wallhaven-tags.json")
    items, seen = [], set()
    if folder.is_dir():
        for parent, dirs, files in os.walk(folder):
            dirs[:] = sorted(d for d in dirs if not d.startswith("."))
            for name in sorted(files):
                path = Path(parent) / name
                if path.suffix.lower() not in IMAGES | VIDEOS:
                    continue
                try:
                    resolved = str(path.resolve())
                    if resolved in seen:
                        continue
                    seen.add(resolved)
                    stat = path.stat()
                    thumb = CACHE / "thumbs" / (thumbnail_key(path) + ".jpg")
                    metadata = read_json(thumb.with_suffix(".json"))
                    if not thumb.with_name(thumb.stem + ".bg.jpg").is_file(): metadata.pop("backdrop", None)
                    valid_thumbnail = thumb.is_file() and metadata.get("color") and metadata.get("dimensions")
                    metadata.update(color_metrics(metadata.get("color")))
                    items.append(dict(path=str(path), name=name, folder=str(Path(parent).relative_to(folder)),
                                      type="video" if path.suffix.lower() in VIDEOS else "static",
                                      mtime=stat.st_mtime, favorite=str(path) in favorites,
                                      thumb=thumb.as_uri() if valid_thumbnail else "", **metadata,
                                      **local_metadata(path, tag_index)))
                except OSError:
                    continue
    items.sort(key=lambda i: (-i["mtime"], i["name"]))
    emit("catalog", items=items, folder=str(folder), current=current_wallpaper(), settings=settings)
    missing = [item for item in items if not item.get("thumb") or not item.get("palette") or not item.get("backdrop")]
    # Exactly two decoders; thumbnails arrive incrementally, after the UI opens.
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        pending = {pool.submit(make_thumbnail, item): item for item in missing}
        for task in concurrent.futures.as_completed(pending):
            try:
                emit("thumbnail", **task.result())
            except Exception:
                emit("thumbnail-error", path=pending[task]["path"])
    emit("ready")
    trim_cache()


def remote_json(url, authenticated=True):
    wallhaven = skwd_config().get("wallhaven", {})
    key = wallhaven.get("apiKey") or wallhaven.get("api_key", "")
    if authenticated and key and urllib.parse.urlparse(url).hostname == "wallhaven.cc":
        url += ("&" if "?" in url else "?") + urllib.parse.urlencode({"apikey": key})
    request = urllib.request.Request(url, headers={"User-Agent": "KingstraWallpaperPicker/1.1 (https://github.com/JorisKooistra/kingstra-dots)"})
    with urllib.request.urlopen(request, timeout=25) as response:
        return json.load(response)


def remote_thumbnail(item):
    from PIL import Image
    target = CACHE / "remote" / (item["id"] + ".jpg")
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.is_file():
        fd, temp = tempfile.mkstemp(dir=target.parent, suffix=".jpg")
        try:
            request = urllib.request.Request(item["remoteThumb"], headers={"User-Agent": "KingstraWallpaperPicker/1.0"})
            with os.fdopen(fd, "wb") as output, urllib.request.urlopen(request, timeout=12) as response:
                payload = response.read(5 * 1024 * 1024 + 1)
                if len(payload) > 5 * 1024 * 1024:
                    raise ValueError("Thumbnail is te groot")
                output.write(payload)
            with Image.open(temp) as image:
                image.verify()
            os.replace(temp, target)
        finally:
            with contextlib.suppress(FileNotFoundError): os.unlink(temp)
    metadata = read_json(target.with_suffix(".json"))
    if not metadata.get("palette") or not target.with_name(target.stem + ".bg.jpg").is_file():
        with Image.open(target) as image: metadata = image_details(image, target)
        atomic_json(target.with_suffix(".json"), metadata)
    return dict(path=item["id"], thumb=target.as_uri(), **metadata)


def trim_cache():
    # Interrupted workers can leave an unpublished temporary file. Network and
    # decoder timeouts are far shorter than this grace period.
    for folder in ("thumbs", "remote", "search", "previews"):
        for path in (CACHE / folder).glob("*"):
            if path.name.startswith((".picker-", ".wallhaven-", "tmp")):
                with contextlib.suppress(OSError):
                    if time.time() - path.stat().st_mtime > 3600: path.unlink()
    # Bound accumulated thumbnails across years of local edits / online pages.
    files = [p for folder in ("thumbs", "remote", "search", "previews") for p in (CACHE / folder).glob("*") if p.is_file()]
    sizes = []
    for path in files:
        with contextlib.suppress(OSError): sizes.append((path, path.stat()))
    total = sum(stat.st_size for _, stat in sizes)
    for path, stat in sorted(sizes, key=lambda row: row[1].st_mtime):
        if total <= 512 * 1024 * 1024:
            break
        # Never evict this session's newly generated/visible images.
        if time.time() - stat.st_mtime > 86400:
            with contextlib.suppress(OSError):
                path.unlink()
                total -= stat.st_size


def trim_previews(keep, budget=256 * 1024 * 1024):
    # Full images are much larger than thumbnails. Bound them immediately,
    # while keeping the file currently being handed to the preview window.
    entries = []
    for path in (CACHE / "previews").glob("*"):
        with contextlib.suppress(OSError):
            if path.is_file(): entries.append((path, path.stat()))
    total = sum(stat.st_size for _, stat in entries)
    for path, stat in sorted(entries, key=lambda entry: entry[1].st_mtime):
        if total <= budget: break
        if path == keep: continue
        with contextlib.suppress(OSError):
            path.unlink()
            total -= stat.st_size


def saved_wallhaven(identifier):
    folder = library()
    stem = identifier if identifier.startswith(("nasa-", "commons-")) else "wallhaven-" + identifier
    return next((str(folder / (stem + suffix)) for suffix in sorted(IMAGES)
                 if (folder / (stem + suffix)).is_file()), "")


def search(args):
    if getattr(args, "source", "wallhaven") == "commons":
        return search_commons(args)
    if getattr(args, "source", "wallhaven") == "nasa":
        return search_nasa(args)
    params = dict(q=args.query, page=args.page, sorting=args.sort, categories=args.categories,
                  purity=args.purity, order="desc", topRange="1M")
    if args.color:
        params["colors"] = args.color
    if args.atleast:
        params["atleast"] = args.atleast
    if args.ratios:
        params["ratios"] = args.ratios
    if getattr(args,"seed",""):
        params["seed"] = args.seed
    # Cache authenticated searches separately without storing keys in filenames.
    auth = skwd_config().get("wallhaven", {})
    cache_key = hashlib.sha256((json.dumps(params, sort_keys=True) + json.dumps(auth, sort_keys=True)).encode()).hexdigest()
    cached = CACHE / "search" / (cache_key + ".json")
    data = read_json(cached)
    if not data or time.time() - cached.stat().st_mtime > 300:
        data = remote_json("https://wallhaven.cc/api/v1/search?" + urllib.parse.urlencode(params))
        atomic_json(cached, data)
    items = []
    for wall in data.get("data", []):
        identifier = wall.get("id", "")
        if not re.fullmatch(r"[a-z0-9]{6}", identifier):
            continue
        thumb = wall.get("thumbs", {}).get("large", "")
        if not valid_url(thumb, {"th.wallhaven.cc"}):
            continue
        if valid_url(wall.get("path", ""), {"w.wallhaven.cc"}):
            # Search already tells us where the full image lives. Its bytes and
            # the richer tag metadata can be fetched concurrently on first save.
            atomic_json(CACHE / "search" / ("wallhaven-" + identifier + ".json"), wall)
        local_thumb = CACHE / "remote" / (identifier + ".jpg")
        items.append(dict(id=identifier, name="wallhaven-" + identifier,
                          thumb=local_thumb.as_uri() if local_thumb.is_file() else "", remoteThumb=thumb,
                          path=saved_wallhaven(identifier), type="static", dimensions=wall.get("resolution", ""),
                          color=(wall.get("colors") or ["#777777"])[0], favorite=False,
                          colors=wall.get("colors", []), tags=read_json(CACHE / "metadata" / (identifier + ".json")).get("tag_names", []),
                          **cached_visuals(local_thumb)))
    emit("search", items=items, page=data.get("meta", {}).get("current_page", args.page),
         lastPage=data.get("meta", {}).get("last_page", 1),seed=data.get("meta",{}).get("seed", ""))
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        tasks = [pool.submit(remote_thumbnail, item) for item in items if not item["thumb"] or not item.get("palette") or not item.get("backdrop")]
        for task in concurrent.futures.as_completed(tasks):
            try: emit("thumbnail", **task.result())
            except Exception: pass  # A failed preview must not hide the results.
    trim_cache()


def search_nasa(args):
    params = dict(media_type="image", page=args.page, page_size=24)
    if args.query.strip(): params["q"] = args.query.strip()
    cache_key = hashlib.sha256(json.dumps(params, sort_keys=True).encode()).hexdigest()
    cached = CACHE / "search" / ("nasa-" + cache_key + ".json")
    data = read_json(cached)
    if not data or time.time() - cached.stat().st_mtime > 300:
        data = remote_json("https://images-api.nasa.gov/search?" + urllib.parse.urlencode(params), authenticated=False)
        atomic_json(cached, data)
    collection = data.get("collection", {})
    items = []
    for entry in collection.get("items", []):
        metadata = next((row for row in entry.get("data", []) if row.get("media_type") == "image"), {})
        original_id = metadata.get("nasa_id", "")
        if not original_id: continue
        identifier = "nasa-" + hashlib.sha256(original_id.encode()).hexdigest()[:24]
        links = [link for link in entry.get("links", []) if link.get("render") == "image"
                 and valid_url(link.get("href", ""), {"images-assets.nasa.gov"})]
        if not links: continue
        # Legacy NASA thumbnails can be only 75px wide. Use a sized alternate
        # for the large center card, without fetching the full original.
        alternates = [link for link in links if link.get("rel") != "canonical"]
        usable = [link for link in alternates if link.get("width", 0) >= 768]
        thumb = min(usable, key=lambda link: link["width"]) if usable else max(alternates or links, key=lambda link: link.get("width", 0))
        original = next((link for link in links if link.get("rel") == "canonical" and Path(urllib.parse.urlparse(link["href"]).path).suffix.lower() in IMAGES), {})
        local = saved_wallhaven(identifier)
        previous = read_json(CACHE / "metadata" / (identifier + ".json"))
        width, height = original.get("width", 0), original.get("height", 0)
        record = dict(source="nasa", id=identifier, nasa_id=original_id,
                      name=metadata.get("title", original_id), path=local or previous.get("path", ""),
                      url="https://images.nasa.gov/details/" + urllib.parse.quote(original_id, safe=""),
                      download_url=original.get("href", "") or previous.get("download_url", ""),
                      tag_names=metadata.get("keywords", []), uploader=metadata.get("secondary_creator") or metadata.get("photographer") or metadata.get("center", "NASA"),
                      resolution=f"{width} × {height}" if width and height else previous.get("resolution", ""),
                      description=metadata.get("description", ""), colors=[],
                      fetched_at=datetime.datetime.now(datetime.timezone.utc).isoformat())
        atomic_json(CACHE / "metadata" / (identifier + ".json"), record)
        local_thumb = CACHE / "remote" / (identifier + ".jpg")
        items.append(dict(id=identifier, name=record["name"], source="nasa", page=record["url"],
                          path=local, type="static", favorite=False, dimensions=record["resolution"],
                          tags=record["tag_names"], thumb=local_thumb.as_uri() if local_thumb.is_file() else "", remoteThumb=thumb["href"],
                          **cached_visuals(local_thumb)))
    total = collection.get("metadata", {}).get("total_hits", 0)
    emit("search", items=items, page=args.page, lastPage=max(args.page, math.ceil(total / 24)))
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        tasks = [pool.submit(remote_thumbnail, item) for item in items if not item["thumb"] or not item.get("palette") or not item.get("backdrop")]
        for task in concurrent.futures.as_completed(tasks):
            try: emit("thumbnail", **task.result())
            except Exception: pass
    trim_cache()


def plain_text(value):
    class Text(HTMLParser):
        def __init__(self): super().__init__(); self.parts = []
        def handle_data(self, data): self.parts.append(data)
    parser = Text()
    parser.feed(str(value or ""))
    return " ".join(html.unescape("".join(parser.parts)).split())


def search_commons(args):
    query = args.query.strip() or "landscape"
    width, height = 1920, 1080
    if args.atleast:
        match = re.fullmatch(r"([1-9][0-9]{1,4})[x×]([1-9][0-9]{1,4})", args.atleast)
        if not match: raise ValueError("Gebruik een resolutie zoals 1920x1080")
        width, height = map(int, match.groups())
    params = dict(action="query", format="json", formatversion=2, generator="search", gsrnamespace=6,
                  gsrsearch=f"{query} filetype:bitmap filew:>{width - 1} fileh:>{height - 1}",
                  gsrlimit=24, gsroffset=(args.page - 1) * 24, prop="imageinfo", iiurlwidth=768,
                  iiprop="url|size|extmetadata|badfile", iiextmetadatalanguage="en",
                  iiextmetadatafilter="ObjectName|Artist|LicenseShortName|LicenseUrl|Categories")
    key = hashlib.sha256(json.dumps(params, sort_keys=True).encode()).hexdigest()
    cached = CACHE / "search" / ("commons-" + key + ".json")
    data = read_json(cached)
    if not data or time.time() - cached.stat().st_mtime > 3600:
        data = remote_json("https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode(params), authenticated=False)
        if data.get("error"): raise ValueError("Commons kon deze zoekopdracht niet uitvoeren")
        atomic_json(cached, data)
    items = []
    for page in sorted(data.get("query", {}).get("pages", []), key=lambda row: row.get("index", 0)):
        info = next(iter(page.get("imageinfo", [])), {})
        url, thumb = info.get("url", ""), info.get("thumburl", "")
        if info.get("badfile") or not valid_url(url, {"upload.wikimedia.org"}) or not valid_url(thumb, {"thumb.wikimedia.org", "upload.wikimedia.org"}): continue
        if Path(urllib.parse.urlparse(url).path).suffix.lower() not in IMAGES or info.get("size", 0) > 100 * 1024 * 1024: continue
        identifier = "commons-" + str(int(page["pageid"]))
        extra = info.get("extmetadata", {})
        field = lambda name: plain_text(extra.get(name, {}).get("value", ""))
        categories = [tag for tag in field("Categories").split("|") if tag]
        tags = [tag for tag in categories if not re.search(r"^(?:Self-published|Photos by |Photographs taken|Images with |Files |Uploaded |Taken with |CC-|Featured pictures on|Quality images|Media |PD-)", tag, re.I)][:12]
        saved = saved_wallhaven(identifier)
        previous = read_json(CACHE / "metadata" / (identifier + ".json"))
        record = dict(source="commons", id=identifier, pageid=page["pageid"],
                      name=field("ObjectName") or page.get("title", "").removeprefix("File:"),
                      path=saved or previous.get("path", ""), download_url=url,
                      url="https://commons.wikimedia.org/wiki/" + urllib.parse.quote(page["title"].replace(" ", "_"), safe=":"),
                      uploader=field("Artist"), license=field("LicenseShortName"), license_url=field("LicenseUrl"),
                      tag_names=tags, categories=categories, resolution=f"{info.get('width', 0)} × {info.get('height', 0)}",
                      fetched_at=datetime.datetime.now(datetime.timezone.utc).isoformat())
        atomic_json(CACHE / "metadata" / (identifier + ".json"), record)
        local_thumb = CACHE / "remote" / (identifier + ".jpg")
        items.append(dict(id=identifier, name=record["name"], source="commons", page=record["url"],
                          path=saved, type="static", favorite=False, dimensions=record["resolution"],
                          tags=tags, credit=record["uploader"], license=record["license"], remoteThumb=thumb,
                          thumb=local_thumb.as_uri() if local_thumb.is_file() else "", **cached_visuals(local_thumb)))
    emit("search", items=items, page=args.page, lastPage=args.page + (1 if items and "gsroffset" in data.get("continue", {}) else 0))
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        tasks = [pool.submit(remote_thumbnail, item) for item in items if not item["thumb"] or not item.get("palette") or not item.get("backdrop")]
        for task in concurrent.futures.as_completed(tasks):
            try: emit("thumbnail", **task.result())
            except Exception: pass
    trim_cache()


def download_public(identifier, preview=False):
    if not re.fullmatch(r"(?:nasa-[a-f0-9]{24}|commons-[1-9][0-9]{0,11})", identifier): raise ValueError("Ongeldig afbeelding-ID")
    source = "commons" if identifier.startswith("commons-") else "nasa"
    hosts = {"upload.wikimedia.org"} if source == "commons" else {"images-assets.nasa.gov"}
    record = read_json(CACHE / "metadata" / (identifier + ".json"))
    if record.get("source") != source or record.get("id") != identifier:
        raise ValueError("Zoek deze afbeelding opnieuw op")
    url = record.get("download_url", "")
    if not url and source == "nasa":
        manifest = remote_json("https://images-api.nasa.gov/asset/" + urllib.parse.quote(record["nasa_id"], safe=""), authenticated=False)
        candidates = [item.get("href", "") for item in manifest.get("collection", {}).get("items", [])]
        candidates = [value for value in candidates if valid_url(value, {"images-assets.nasa.gov"}) and Path(urllib.parse.urlparse(value).path).suffix.lower() in IMAGES]
        url = next((value for value in candidates if "~orig." in value), next(iter(candidates), ""))
        record["download_url"] = url
    if not valid_url(url, hosts): raise ValueError("Ongeldig downloadadres")
    suffix = Path(urllib.parse.urlparse(url).path).suffix.lower()
    if suffix not in IMAGES: raise ValueError("Onbekend afbeeldingsformaat")
    saved = saved_wallhaven(identifier)
    folder = CACHE / "previews" if preview else library()
    folder.mkdir(parents=True, exist_ok=True)
    target = Path(saved) if saved else folder / (identifier + suffix)
    transfer_image(url, target, hosts, CACHE / "previews" / (identifier + suffix))
    from PIL import Image
    with Image.open(target) as image: record["resolution"] = f"{image.width} × {image.height}"
    record["path"] = str(target)
    atomic_json(CACHE / "metadata" / (identifier + ".json"), record)
    if not preview: atomic_json(metadata_file(target), record)
    if preview:
        os.utime(target, None)
        trim_previews(target)
        emit("preview", id=identifier, path=str(target), url=target.as_uri(), dimensions=record["resolution"],
             uploader=record.get("uploader", ""), tags=record.get("tag_names", []), page=record["url"],
             source=source, license=record.get("license", ""))
    else: emit("download", id=identifier, path=str(target), tags=record.get("tag_names", []))


def transfer_image(url, target, hosts, cached=None):
    """Publish only verified, complete images; reuse a verified HD preview."""
    from PIL import Image
    if target.is_file():
        try:
            with Image.open(target) as image: image.verify()
            return
        except (OSError, ValueError): target.unlink()
    fd, temp = tempfile.mkstemp(dir=target.parent, prefix=".picker-", suffix=target.suffix)
    try:
        with os.fdopen(fd, "wb") as output:
            reuse = False
            if cached and cached.is_file() and cached != target:
                try:
                    with Image.open(cached) as image: image.verify()
                    with cached.open("rb") as source: shutil.copyfileobj(source, output)
                    reuse = True
                except (OSError, ValueError): output.seek(0); output.truncate()
            if not reuse:
                emit("progress", stage="download", label="Afbeelding downloaden…", percent=-1)
                request = urllib.request.Request(url, headers={"User-Agent": "KingstraWallpaperPicker/1.1"})
                with urllib.request.urlopen(request, timeout=45) as response:
                    if not valid_url(response.url, hosts): raise ValueError("Onverwachte downloadredirect")
                    expected = int(response.headers.get("Content-Length", 0)) if hasattr(response, "headers") else 0
                    total, last = 0, 0
                    while chunk := response.read(256 * 1024):
                        total += len(chunk)
                        if total > 100 * 1024 * 1024: raise ValueError("Afbeelding is groter dan 100 MB")
                        output.write(chunk)
                        if time.monotonic() - last > .12:
                            last = time.monotonic()
                            emit("progress", stage="download", label="Afbeelding downloaden…", percent=min(100, round(total * 100 / expected)) if expected else -1, bytes=total)
                    if expected and total != expected: raise ValueError("Download onderbroken; probeer opnieuw")
        with Image.open(temp) as image: image.verify()
        os.replace(temp, target)
    finally:
        with contextlib.suppress(FileNotFoundError): os.unlink(temp)


def valid_url(url, hosts):
    parsed = urllib.parse.urlparse(url)
    return parsed.scheme == "https" and parsed.hostname in hosts and parsed.port in (None, 443)


def download(identifier, preview=False):
    if identifier.startswith(("nasa-", "commons-")):
        return download_public(identifier, preview)
    if not re.fullmatch(r"[a-z0-9]{6}", identifier):
        raise ValueError("Ongeldig Wallhaven-ID")
    if preview:
        record = read_json(CACHE / "metadata" / (identifier + ".json"))
        candidate = saved_wallhaven(identifier) or record.get("path", "")
        if record.get("id") == identifier and candidate:
            path = Path(candidate)
            if path.is_file() and (path.parent == CACHE / "previews" or str(path) == saved_wallhaven(identifier)):
                from PIL import Image
                try:
                    with Image.open(path) as image: image.verify()
                    emit("preview", path=str(path), id=identifier, url=path.as_uri(),
                         dimensions=record.get("resolution", ""), size=path.stat().st_size,
                         uploader=record.get("uploader", ""), tags=record.get("tag_names", []),
                         colors=record.get("colors", []), page="https://wallhaven.cc/w/" + identifier)
                    return
                except (OSError, ValueError): pass
    record = read_json(CACHE / "metadata" / (identifier + ".json"))
    data = record.get("data", {}) if record.get("id") == identifier else {}
    candidate = Path(record.get("path") or "/nonexistent")
    if not preview and not data.get("path") and record.get("id") == identifier and candidate.is_file() and candidate.parent == CACHE / "previews" and candidate.stem == "wallhaven-" + identifier and candidate.suffix.lower() in IMAGES:
        # Also reuse previews cached by the previous picker version, whose
        # sidecars contain normalized tags but no raw detail response.
        target = library() / candidate.name
        target.parent.mkdir(parents=True, exist_ok=True)
        transfer_image("", target, {"w.wallhaven.cc"}, candidate)
        atomic_json(metadata_file(target), dict(record, path=str(target)))
        atomic_json(CACHE / "metadata" / (identifier + ".json"), dict(record, path=str(target)))
        emit("download", id=identifier, path=str(target), tags=record.get("tag_names", []))
        return
    seed = read_json(CACHE / "search" / ("wallhaven-" + identifier + ".json"))
    # A small, provider-validated search record lets an image transfer run at
    # the same time as the detail request, instead of waiting for it to finish.
    if not data.get("path") and valid_url(seed.get("path", ""), {"w.wallhaven.cc"}):
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
            details = pool.submit(remote_json, "https://wallhaven.cc/api/v1/w/" + identifier)
            url = seed["path"]
            suffix = Path(urllib.parse.urlparse(url).path).suffix.lower()
            if suffix not in IMAGES: raise ValueError("Onbekend afbeeldingsformaat")
            folder = CACHE / "previews" if preview else library()
            folder.mkdir(parents=True, exist_ok=True)
            transfer_image(url, folder / ("wallhaven-" + identifier + suffix), {"w.wallhaven.cc"},
                           CACHE / "previews" / ("wallhaven-" + identifier + suffix))
            data = details.result()["data"]
    if not data.get("path"):
        emit("progress", stage="metadata", label="Wallhaven-gegevens ophalen…", percent=-1)
        data = remote_json("https://wallhaven.cc/api/v1/w/" + identifier)["data"]
    url = data["path"]
    if not valid_url(url, {"w.wallhaven.cc"}):
        raise ValueError("Ongeldig downloadadres")
    suffix = Path(urllib.parse.urlparse(url).path).suffix.lower()
    if suffix not in IMAGES:
        raise ValueError("Onbekend afbeeldingsformaat")
    folder = CACHE / "previews" if preview else library()
    folder.mkdir(parents=True, exist_ok=True)
    target = folder / ("wallhaven-" + identifier + suffix)
    transfer_image(url, target, {"w.wallhaven.cc"}, CACHE / "previews" / target.name)
    record = remember_wallhaven(identifier, data, target, save_sidecar=not preview)
    if preview:
        os.utime(target, None)
        trim_previews(target)
        emit("preview", path=str(target), id=identifier, url=target.as_uri(),
             dimensions=data.get("resolution", ""), size=data.get("file_size", 0),
             uploader=(data.get("uploader") or {}).get("username", ""),
             tags=record["tag_names"],
             colors=data.get("colors", []), page="https://wallhaven.cc/w/" + identifier)
    else:
        emit("download", path=str(target), id=identifier, tags=record["tag_names"])


def remove(identifier):
    if not re.fullmatch(r"(?:[a-z0-9]{6}|nasa-[a-f0-9]{24}|commons-[1-9][0-9]{0,11})", identifier):
        raise ValueError("Ongeldig wallpaper-ID")
    saved = saved_wallhaven(identifier)
    if not saved:
        emit("removed", id=identifier, path="", remaining="")
        return
    path = Path(saved)
    current = current_wallpaper()
    if current and Path(current).resolve() == path.resolve():
        raise ValueError("Kies eerst een andere wallpaper voordat je deze verwijdert")
    gio = shutil.which("gio")
    if not gio:
        raise ValueError("De prullenbak is niet beschikbaar")
    files = [str(path)]
    if metadata_file(path).is_file(): files.append(str(metadata_file(path)))
    result = subprocess.run([gio, "trash", *files], capture_output=True)
    if result.returncode: raise ValueError("Naar de prullenbak verplaatsen is niet gelukt")
    emit("removed", id=identifier, path=str(path), remaining=saved_wallhaven(identifier))


def apply(path):
    path = Path(path).resolve(strict=True)
    if not path.is_file() or path.suffix.lower() not in IMAGES | VIDEOS:
        raise ValueError("Geen ondersteund wallpaperbestand")
    helper = Path(__file__).resolve().parents[2] / "wallpaper/kingstra-wallpaper"
    env = dict(os.environ, PATH=str(HOME / ".local/bin") + ":" + os.environ.get("PATH", ""))
    mode = "video" if path.suffix.lower() in VIDEOS else "set"
    # Stream renderer/palette milestones while slower app refreshes finish.
    # The separate process group lets closing the picker finish the apply.
    env["KINGSTRA_PICKER_EVENTS"] = "1"
    emit("progress", stage="apply", label="Wallpaper instellen…", percent=-1)
    process = subprocess.Popen(["bash", str(helper), mode, str(path)], env=env,
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               text=True, start_new_session=True)
    for line in process.stdout:
        marker = line.strip()
        if marker == "KINGSTRA_PICKER_WALLPAPER_SET":
            emit("wallpaper-set", path=str(path))
            emit("progress", stage="colors", label="Kleuren bijwerken…", percent=-1)
        elif marker == "KINGSTRA_PICKER_PALETTE_READY":
            emit("progress", stage="apps", label="Wallpaper ingesteld · apps bijwerken…", percent=-1)
    if process.wait():
        raise ValueError("Wallpaper toepassen is niet afgerond. Probeer opnieuw.")
    emit("applied", path=str(path))


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("catalog")
    prefs = sub.add_parser("preferences")
    prefs.add_argument("key")
    prefs.add_argument("value")
    find = sub.add_parser("search")
    find.add_argument("--source", choices=["wallhaven", "nasa", "commons"], default="wallhaven")
    find.add_argument("--query", default="")
    find.add_argument("--page", type=int, default=1)
    find.add_argument("--sort", choices=["toplist", "date_added", "random", "favorites", "views"], default="toplist")
    find.add_argument("--categories", choices=["111", "100", "010", "001"], default="111")
    find.add_argument("--purity", choices=["100", "110", "111"], default="100")
    find.add_argument("--color", default="")
    find.add_argument("--atleast", default="")
    find.add_argument("--ratios", default="")
    find.add_argument("--seed", default="")
    sub.add_parser("download").add_argument("id")
    sub.add_parser("preview").add_argument("id")
    sub.add_parser("remove").add_argument("id")
    sub.add_parser("apply").add_argument("path")
    args = parser.parse_args()
    try:
        if args.command == "catalog": catalog()
        elif args.command == "preferences": preferences(args.key, args.value)
        elif args.command == "search": search(args)
        elif args.command == "download": download(args.id)
        elif args.command == "preview": download(args.id, preview=True)
        elif args.command == "remove": remove(args.id)
        elif args.command == "apply": apply(args.path)
    except urllib.error.HTTPError as error:
        source = getattr(args, "source", "") or str(getattr(args, "id", "")).split("-")[0]
        provider = {"nasa": "NASA", "commons": "Commons"}.get(source, "Wallhaven")
        messages = {401: "Wallhaven: controleer je API-sleutel", 403: "Wallhaven weigert de aanvraag",
                    429: "Wallhaven-limiet bereikt; probeer het straks opnieuw"}
        emit("error", message=messages.get(error.code, f"{provider} geeft HTTP {error.code}") if provider == "Wallhaven" else f"{provider} geeft HTTP {error.code}; probeer straks opnieuw")
        return 1
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        # Never include authenticated request URLs in errors.
        emit("error", message=str(error) if isinstance(error, ValueError) else "Kon de aanvraag niet afronden. Probeer opnieuw.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
