"""Private fixtures for wallpaper-picker-offscreen.py; never installs/applies.

The actual catalog, thumbnail generation and preferences worker are exercised.
Only remote I/O and desktop wallpaper changes are replaced.
"""
import hashlib
import json
import os
from pathlib import Path
import runpy
import shutil
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
BASE = Path(os.environ["KINGSTRA_PICKER_TEST_DIR"])
LIBRARY = BASE / "library"


def emit(event, **data):
    print(json.dumps(dict(event=event, **data)), flush=True)


def fixture_index(identifier):
    return int(hashlib.sha256(identifier.encode()).hexdigest()[:6], 16) % 48


def main():
    command = sys.argv[1]
    if command in {"catalog", "preferences"} or (os.environ.get("KINGSTRA_PICKER_LIVE_API") == "1" and command in {"search", "preview", "download"}):
        if command == "preferences": time.sleep(.6)
        runpy.run_path(str(ROOT / "config/quickshell/wallpaper/backend.py"), run_name="__main__")
    elif command == "search":
        args = dict(zip(sys.argv[2::2], sys.argv[3::2]))
        query, color, page = args["--query"], args["--color"], int(args["--page"])
        with (BASE / "searches.jsonl").open("a") as output:
            output.write(json.dumps(args) + "\n")
        if query == "fout" and not (BASE / "retried").exists():
            (BASE / "retried").touch()
            emit("error", message="Testverbinding onderbroken; probeer opnieuw")
            sys.exit(1)
        time.sleep(1.3 if query == "traag" else (.8 if query.startswith("paging-") and page>1 else .2))
        source = args.get("--source", "wallhaven")
        prefix = hashlib.sha256((query + color + source).encode()).hexdigest()[:2]
        backend=runpy.run_path(str(ROOT / "config/quickshell/wallpaper/backend.py"),run_name="fixture")
        items = []
        for index in range((page - 1) * 24, page * 24):
            identifier = prefix + f"{index:04}"
            if source == "nasa": identifier = "nasa-" + hashlib.sha256(identifier.encode()).hexdigest()[:24]
            elif source == "commons": identifier = "commons-" + str(int(prefix,16)*10000 + index + 1)
            image = LIBRARY / f"fixture-{index % 48:02}.jpg"
            thumb = image.as_uri()
            details = backend["cached_visuals"](backend["CACHE"] / "thumbs" / (backend["thumbnail_key"](image) + ".jpg"))
            items.append(dict(id=identifier, name=f"{query or 'wallhaven'}-{color}-{identifier}",
                              path="", source=source, page="https://images.nasa.gov/details/fixture" if source=="nasa" else "", thumb=thumb, dimensions="960x600", type="static", favorite=False,tags=["landscape", "colorful"], **details))
        emit("search", items=items, page=page, lastPage=6, seed="fixedseed")
    elif command == "preview":
        slow = BASE / "slow-next-preview"
        if slow.exists():
            slow.unlink()
            time.sleep(1.5)
        else: time.sleep(.12)
        marker = BASE / "fail-next-preview"
        if marker.exists():
            marker.unlink()
            emit("error", message="Previewtest: verbinding onderbroken")
            sys.exit(1)
        identifier = sys.argv[2]
        path = LIBRARY / f"fixture-{fixture_index(identifier):02}.jpg"
        from PIL import Image
        full = BASE / "full" / (identifier + ".jpg")
        full.parent.mkdir(exist_ok=True)
        with Image.open(path) as image: image.resize((1600,1000)).save(full)
        path = full
        (BASE / ("preview-ready-" + identifier)).touch()
        emit("preview", id=identifier, path=str(path), url=path.as_uri(), dimensions="960x600", uploader="Fixture maker", tags=["landscape", "<plain text>"])
    elif command == "download":
        identifier = sys.argv[2]
        if (BASE / "expect-preview-before-save").exists():
            assert (BASE / ("preview-ready-" + identifier)).is_file(), "save raced the pending HD preview"
        path = LIBRARY / ((identifier if identifier.startswith(("nasa-", "commons-")) else "wallhaven-" + identifier) + ".jpg")
        shutil.copyfile(LIBRARY / f"fixture-{fixture_index(identifier):02}.jpg", path)
        backend=runpy.run_path(str(ROOT / "config/quickshell/wallpaper/backend.py"),run_name="fixture")
        if identifier.startswith(("nasa-", "commons-")):
            backend["atomic_json"](backend["metadata_file"](path), dict(source="commons" if identifier.startswith("commons-") else "nasa",tag_names=["fixture-tag"],uploader="Fixture author",license="CC BY 4.0"))
        else:
            backend["remember_wallhaven"](identifier,{"tags":[{"name":"fixture-tag"}],"resolution":"960x600"},path,True)
        emit("download", id=identifier, path=str(path),tags=["fixture-tag"])
    elif command == "remove":
        identifier=sys.argv[2]
        path=LIBRARY/((identifier if identifier.startswith(("nasa-", "commons-")) else "wallhaven-"+identifier)+".jpg")
        path.unlink(missing_ok=True)
        Path(str(path)+".json").unlink(missing_ok=True)
        emit("removed",id=identifier,path=str(path),remaining="")
    elif command == "apply":
        emit("wallpaper-set", path=sys.argv[2])
        emit("progress", stage="colors",label="Kleuren bijwerken…",percent=-1)
        time.sleep(.15)
        (BASE / "applied.log").write_text(sys.argv[2])
        emit("applied", path=sys.argv[2])


if __name__ == "__main__":
    main()
