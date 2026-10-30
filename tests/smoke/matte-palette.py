#!/usr/bin/env python3
"""Matte dempt wallpaperkleuren en behoudt leesbare accentknoppen."""
import colorsys
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[2]
helper = runpy.run_path(str(ROOT / "config/shared/scripts/kingstra-matte-palette"))
for hue in range(0, 360, 15):
    raw = "#" + "".join(f"{round(v * 255):02x}" for v in colorsys.hls_to_rgb(hue / 360, .8, .9))
    source = {"colors": {"dark": {"primary": raw, "on_primary": "#272932", "background": "#12130c", "on_surface": "#fafafa", "error": "#ffb4ab"}}}
    result = helper["transform"](source, "dark")["colors"]["dark"]
    assert source["colors"]["dark"]["primary"] == raw, "input gewijzigd"
    rgb = [int(result["primary"][i:i+2], 16) / 255 for i in (1, 3, 5)]
    h, _, s = colorsys.rgb_to_hls(*rgb)
    assert min(abs(h - hue / 360), 1 - abs(h - hue / 360)) < .01, "wallpapertint verloren"
    assert s <= .35, "accent te verzadigd"
    assert helper["contrast"](result["primary"], result["on_primary"]) >= 4.5, "knoptekst onleesbaar"
    assert helper["contrast"](result["on_surface"], result["background"]) >= 7, "paneeltekst onleesbaar"
    assert result["error"] == "#ffb4ab", "foutkleur afgezwakt"
assert helper["tone"]("geen kleur", "primary") == "geen kleur"
print("Matte-palet: 24 tinten, kleurbehoud en tekstcontrast OK")
