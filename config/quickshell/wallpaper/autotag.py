"""Offline tags for wallpapers that came without metadata (own photos, drops).

Only looks at the pixels, the EXIF block and the file name: no network, no
model download. Dutch tag names with an English alias, so searching "blauw"
and "blue" both match. The result is stored as `<file>.json` next to the image
with source "kingstra-auto", the same sidecar the picker already reads.
"""
import datetime
import re
import warnings
from pathlib import Path

VERSION = 2
SOURCE = "kingstra-auto"

# Hue ranges in degrees → (Dutch, English). Red wraps around 0.
HUES = [(15, "rood", "red"), (40, "oranje", "orange"), (70, "geel", "yellow"), (160, "groen", "green"),
        (195, "turquoise", "teal"), (255, "blauw", "blue"), (290, "paars", "purple"), (345, "roze", "pink"),
        (361, "rood", "red")]
WARM = {"rood", "oranje", "geel", "bruin", "roze"}
COOL = {"groen", "turquoise", "blauw", "paars"}
MONTHS = ["januari", "februari", "maart", "april", "mei", "juni", "juli", "augustus", "september",
          "oktober", "november", "december"]
SEASONS = {12: ("winter", "winter"), 1: ("winter", "winter"), 2: ("winter", "winter"), 3: ("lente", "spring"),
           4: ("lente", "spring"), 5: ("lente", "spring"), 6: ("zomer", "summer"), 7: ("zomer", "summer"),
           8: ("zomer", "summer"), 9: ("herfst", "autumn"), 10: ("herfst", "autumn"), 11: ("herfst", "autumn")}
ENGLISH = {"donker": "dark", "licht": "bright", "kleurrijk": "colorful", "gedempt": "muted", "zwart-wit": "monochrome",
           "warm": "warm", "koel": "cool", "wit": "white", "zwart": "black", "grijs": "gray", "bruin": "brown",
           "liggend": "landscape", "staand": "portrait", "vierkant": "square", "ultrawide": "ultrawide",
           "4k": "uhd", "eigen foto": "photo", "ochtend": "morning", "middag": "afternoon", "avond": "evening",
           "nacht": "night", "hoge resolutie": "high resolution"}
# File-name noise from cameras, phones and download sites.
NOISE = re.compile(r"^(img|dsc|dscn|dcim|pxl|mvimg|photo|image|foto|screenshot|scherm\w*|wallpaper|wallhaven|"
                   r"edit\w*|copy|kopie|final|jpe?g|png|webp|heic|raw|whatsapp|signal|unsplash|pexels|"
                   r"pixabay|\d+x\d+|\d+k|hd|uhd|fhd|qhd|"
                   # Download-site names and filler words that say nothing about the image.
                   r"com|net|org|www|http|https|moewalls|wallsflow|wallpaperflare|wallpaperaccess|wallpapercave|"
                   r"alphacoders|backiee|wallpaperscraft|motionbgs|desktophut|live|animated|unknown|untitled|"
                   r"the|and|with|for|from|een|het|van|met|der|des|von|und|les|del)$", re.IGNORECASE)


def hue_name(degrees):
    for limit, dutch, english in HUES:
        if degrees < limit:
            return dutch, english
    return "rood", "red"


def colour_tags(image):
    """Dominant colours + overall mood from a small HSV sample."""
    sample = image.convert("RGB").resize((96, 96)).convert("HSV")
    shares, total = {}, 0
    value_sum = saturation_sum = 0.0
    for h, s, v in sample.getdata():
        total += 1
        s, v = s / 255, v / 255
        value_sum += v
        saturation_sum += s
        if v < 0.16: key = ("zwart", "black")
        elif s < 0.16: key = ("wit", "white") if v > 0.82 else ("grijs", "gray")
        else:
            dutch, english = hue_name(h * 360 / 255)
            key = ("bruin", "brown") if dutch in {"oranje", "rood", "geel"} and v < 0.55 and s > 0.3 else (dutch, english)
        shares[key] = shares.get(key, 0) + 1
    shares = {key: count / total for key, count in shares.items()}
    neutral = {"zwart", "wit", "grijs"}
    chromatic = sorted(((share, key) for key, share in shares.items() if key[0] not in neutral), reverse=True)
    tags = [key for share, key in chromatic if share >= 0.12][:3]
    for name in ("zwart", "wit"):
        key = next((k for k in shares if k[0] == name), None)
        if key and shares[key] >= 0.35: tags.append(key)
    colour_share = sum(share for share, _ in chromatic)
    mean_value, mean_saturation = value_sum / total, saturation_sum / total
    mood = []
    if colour_share < 0.06: mood.append("zwart-wit")
    elif mean_saturation > 0.55: mood.append("kleurrijk")
    elif mean_saturation < 0.2: mood.append("gedempt")
    if mean_value < 0.3: mood.append("donker")
    elif mean_value > 0.7: mood.append("licht")
    if colour_share >= 0.15:
        warm = sum(share for share, key in chromatic if key[0] in WARM)
        cool = sum(share for share, key in chromatic if key[0] in COOL)
        if warm >= colour_share * 0.7: mood.append("warm")
        elif cool >= colour_share * 0.7: mood.append("koel")
    return tags + [(name, ENGLISH[name]) for name in mood]


def shape_tags(width, height):
    ratio = width / max(1, height)
    shape = "ultrawide" if ratio >= 2.2 else "liggend" if ratio > 1.05 else "staand" if ratio < 0.95 else "vierkant"
    tags = [shape]
    if max(width, height) >= 3840: tags.append("4k")
    elif max(width, height) >= 2560: tags.append("hoge resolutie")
    return [(name, ENGLISH[name]) for name in tags]


def exif_info(image):
    """Capture date and camera, when the photo still carries EXIF."""
    with_exif = {}
    try:
        exif = image.getexif()
        detail = exif.get_ifd(0x8769)
    except Exception:
        return with_exif
    stamp = detail.get(36867) or detail.get(36868) or exif.get(306)
    if isinstance(stamp, bytes): stamp = stamp.decode(errors="ignore")
    if isinstance(stamp, str):
        try: with_exif["taken"] = datetime.datetime.strptime(stamp.strip()[:19], "%Y:%m:%d %H:%M:%S")
        except ValueError: pass
    make, model = str(exif.get(271) or "").strip(" \0"), str(exif.get(272) or "").strip(" \0")
    if model:
        with_exif["camera"] = model if model.lower().startswith(make.lower().split(" ")[0]) or not make else f"{make} {model}"
    return with_exif


def exif_tags(info):
    tags = []
    if info.get("camera"): tags += [("eigen foto", "photo"), (info["camera"], "camera")]
    taken = info.get("taken")
    if taken:
        tags += [(str(taken.year), str(taken.year)), (MONTHS[taken.month - 1], taken.strftime("%B").lower()), SEASONS[taken.month]]
        part = "ochtend" if 6 <= taken.hour < 12 else "middag" if 12 <= taken.hour < 18 else "avond" if 18 <= taken.hour < 23 else "nacht"
        tags.append((part, ENGLISH[part]))
    return tags


def name_tags(path):
    words = re.split(r"[^0-9A-Za-zÀ-ÿ]+", Path(path).stem)
    keep = [word.lower() for word in words if len(word) >= 3 and not word.isdigit() and not NOISE.match(word)
            and not re.fullmatch(r"[0-9a-f]{6,}", word.lower())]
    return [(word, "") for word in dict.fromkeys(keep)][:6]


def describe(path, frame=None):
    """Tags and colour summary for one image file. Videos pass a still frame."""
    from PIL import Image, ImageOps
    with warnings.catch_warnings(), Image.open(frame or path) as original:
        warnings.simplefilter("ignore")  # Palette-transparency notices from PNGs.
        width, height = original.width, original.height
        info = {} if frame else exif_info(original)
        original.draft("RGB", (512, 512))
        image = ImageOps.exif_transpose(original)
        if image.width != width and image.height == width: width, height = height, width
        shape = shape_tags(width, height)
        if frame: shape = [shape[0], ("video", "animated")]
        tags = name_tags(path) + colour_tags(image) + shape + exif_tags(info)
    unique = {}
    for name, alias in tags:  # A file-name word can repeat a colour: keep its alias.
        tag = unique.setdefault(name.lower(), dict(name=name, alias=alias, category="auto"))
        tag["alias"] = tag["alias"] or alias
    unique = list(unique.values())
    record = dict(source=SOURCE, auto_version=VERSION, path=str(path), tag_names=[tag["name"] for tag in unique],
                  tags=unique,
                  tagged_at=datetime.datetime.now(datetime.timezone.utc).isoformat())
    if not frame: record["resolution"] = f"{width}x{height}"
    if info.get("camera"): record["camera"] = info["camera"]
    if info.get("taken"): record["taken"] = info["taken"].isoformat()
    return record
