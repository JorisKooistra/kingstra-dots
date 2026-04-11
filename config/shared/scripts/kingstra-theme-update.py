#!/usr/bin/env python3
"""kingstra-theme-update.py — Update theme TOML fields from UI.

Usage:
  python3 kingstra-theme-update.py <theme_id> <section.key> <value> [<section.key> <value> ...]

Examples:
  python3 kingstra-theme-update.py rocky appearance.border_radius 18 fonts.ui_font "JetBrains Mono"
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


def main() -> None:
    if len(sys.argv) < 4 or (len(sys.argv) - 2) % 2 != 0:
        die(
            "Gebruik: kingstra-theme-update.py <theme_id> <section.key> <value> "
            "[<section.key> <value> ...]"
        )

    theme_id = sys.argv[1].strip()
    if not SAFE_THEME_ID.match(theme_id):
        die(f"Ongeldige theme_id: {theme_id!r}")

    config_home = os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))
    theme_path = Path(config_home) / "kingstra" / "themes" / f"{theme_id}.toml"
    if not theme_path.is_file():
        die(f"Theme-bestand niet gevonden: {theme_path}")

    try:
        data = tomllib.loads(theme_path.read_text(encoding="utf-8"))
    except Exception as exc:  # pragma: no cover
        die(f"Kon TOML niet lezen: {exc}")

    args = sys.argv[2:]
    for i in range(0, len(args), 2):
        path = args[i].strip()
        raw_value = args[i + 1]
        if "." not in path:
            die(f"Pad moet 'section.key' zijn, kreeg: {path!r}")
        section, key = path.split(".", 1)
        if not section or not key:
            die(f"Ongeldig pad: {path!r}")

        section_obj = data.get(section)
        if section_obj is None:
            section_obj = {}
            data[section] = section_obj
        if not isinstance(section_obj, dict):
            die(f"Sectie '{section}' is geen tabel in {theme_path.name}")

        section_obj[key] = parse_value(raw_value)

    write_toml(data, theme_path)
    print(f"[kingstra-theme-update] bijgewerkt: {theme_path}")


if __name__ == "__main__":
    main()
