#!/usr/bin/env python3
"""kingstra-theme-update.py — Update theme TOML fields from UI.

Usage:
  python3 kingstra-theme-update.py <theme_id> <section.key> <value> [<section.key> <value> ...]

Examples:
  python3 kingstra-theme-update.py neon appearance.border_radius 8 fonts.ui_font "JetBrains Mono"
"""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path
from typing import Any

try:
    import tomllib  # Python 3.11+
except ModuleNotFoundError:  # pragma: no cover
    import tomli as tomllib


SAFE_THEME_ID = re.compile(r"^[A-Za-z0-9_-]+$")
INT_RE = re.compile(r"^-?\d+$")
FLOAT_RE = re.compile(r"^-?(?:\d+\.\d+|\d+\.)$")


def die(msg: str) -> None:
    print(f"[kingstra-theme-update] FOUT: {msg}", file=sys.stderr)
    raise SystemExit(1)


def parse_value(raw: str) -> Any:
    val = raw.strip()
    lower = val.lower()
    if lower == "true":
        return True
    if lower == "false":
        return False
    if INT_RE.match(val):
        try:
            return int(val)
        except ValueError:
            pass
    if FLOAT_RE.match(val):
        try:
            return float(val)
        except ValueError:
            pass
    return raw


def format_value(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        # Keep compact but stable representation for TOML numbers.
        text = f"{value:.6f}".rstrip("0").rstrip(".")
        return text if text else "0"
    if isinstance(value, list):
        inner = ", ".join(format_value(v) for v in value)
        return f"[{inner}]"
    return json.dumps(str(value), ensure_ascii=False)


def write_toml(data: dict[str, Any], out_path: Path) -> None:
    lines: list[str] = []

    # Root scalar keys first (rare in these themes, but supported).
    for key, value in data.items():
        if not isinstance(value, dict):
            lines.append(f"{key} = {format_value(value)}")

    if lines:
        lines.append("")

    # Then section tables in insertion order.
    for section, section_data in data.items():
        if not isinstance(section_data, dict):
            continue
        lines.append(f"[{section}]")
        for key, value in section_data.items():
            lines.append(f"{key} = {format_value(value)}")
        lines.append("")

    text = "\n".join(lines).rstrip() + "\n"
    out_path.write_text(text, encoding="utf-8")


def overrides_file(theme_id: str) -> Path:
    state = os.environ.get("XDG_STATE_HOME") or str(Path.home() / ".local" / "state")
    return Path(state) / "kingstra" / "theme-overrides" / f"{theme_id}.json"


def load_json(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def write_overrides(theme_id: str, data: dict[str, Any]) -> Path:
    out = overrides_file(theme_id)
    data = {k: v for k, v in data.items() if isinstance(v, dict) and v}
    if not data:
        out.unlink(missing_ok=True)
        return out
    out.parent.mkdir(parents=True, exist_ok=True)
    tmp = out.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    tmp.replace(out)
    return out


def main() -> None:
    # Aanpassingen komen niet meer in de thema-toml (die staat in de repo en
    # wordt bij elke update teruggezet), maar in een eigen bestand per thema
    # onder ~/.local/state/kingstra/theme-overrides. kingstra-theme-read legt
    # ze over het thema heen. --reset haalt alles weg: het origineel is terug.
    if len(sys.argv) == 3 and sys.argv[1] in ("--reset", "--show"):
        theme_id = sys.argv[2].strip()
        if not SAFE_THEME_ID.match(theme_id):
            die(f"Ongeldige theme_id: {theme_id!r}")
        if sys.argv[1] == "--reset":
            overrides_file(theme_id).unlink(missing_ok=True)
            print(f"[kingstra-theme-update] origineel terug: {theme_id}")
        else:
            print(json.dumps(load_json(overrides_file(theme_id))))
        return

    if len(sys.argv) < 4 or (len(sys.argv) - 2) % 2 != 0:
        die(
            "Gebruik: kingstra-theme-update.py <theme_id> <section.key> <value> "
            "[<section.key> <value> ...] | --reset <theme_id> | --show <theme_id>"
        )

    theme_id = sys.argv[1].strip()
    if not SAFE_THEME_ID.match(theme_id):
        die(f"Ongeldige theme_id: {theme_id!r}")

    config_home = os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))
    theme_path = Path(config_home) / "kingstra" / "themes" / f"{theme_id}.toml"
    if not theme_path.is_file():
        die(f"Theme-bestand niet gevonden: {theme_path}")

    try:
        base = tomllib.loads(theme_path.read_text(encoding="utf-8"))
    except Exception as exc:  # pragma: no cover
        die(f"Kon TOML niet lezen: {exc}")

    overrides = load_json(overrides_file(theme_id))

    args = sys.argv[2:]
    for i in range(0, len(args), 2):
        path = args[i].strip()
        raw_value = args[i + 1]
        if "." not in path:
            die(f"Pad moet 'section.key' zijn, kreeg: {path!r}")
        section, key = path.split(".", 1)
        if not section or not key:
            die(f"Ongeldig pad: {path!r}")
        base_section = base.get(section, {})
        if not isinstance(base_section, dict):
            die(f"Sectie '{section}' is geen tabel in {theme_path.name}")

        value = parse_value(raw_value)
        section_obj = overrides.setdefault(section, {})
        # Gelijk aan het thema zelf: dan is het geen aanpassing meer.
        if section_obj is not None and base_section.get(key) == value:
            section_obj.pop(key, None)
        else:
            section_obj[key] = value

    out = write_overrides(theme_id, overrides)
    print(f"[kingstra-theme-update] bijgewerkt: {out}")


if __name__ == "__main__":
    main()
