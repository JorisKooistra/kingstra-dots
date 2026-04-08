#!/usr/bin/env python3
"""kingstra-theme-read — Read theme TOML files for shell scripts and QML.

Usage:
    kingstra-theme-read <file.toml>                    # All key=value (shell-sourceable)
    kingstra-theme-read <file.toml> <section.key>      # Single value
    kingstra-theme-read --list <themes_dir>             # JSON array of all themes
    kingstra-theme-read --json <file.toml>              # Full theme as JSON
"""

import sys
import os
import json

try:
    import tomllib  # Python 3.11+
except ModuleNotFoundError:
    import tomli as tomllib  # Fallback


def flatten(d, prefix=""):
    """Flatten nested dict to dot-separated keys."""
    items = {}
    for k, v in d.items():
        key = f"{prefix}{k}" if prefix else k
        if isinstance(v, dict):
            items.update(flatten(v, f"{key}."))
        else:
            items[key] = v
    return items


def read_toml(path):
    with open(path, "rb") as f:
        return tomllib.load(f)


def print_shell_vars(data):
    """Print all values as shell-sourceable KEY=VALUE pairs."""
    flat = flatten(data)
    for k, v in flat.items():
        # Convert dots to underscores for shell compatibility
        shell_key = k.replace(".", "_").upper()
        if isinstance(v, bool):
            print(f'{shell_key}={"true" if v else "false"}')
        elif isinstance(v, (int, float)):
            print(f"{shell_key}={v}")
        else:
            # Quote strings
            print(f'{shell_key}="{v}"')


def get_value(data, dotpath):
    """Get a single value by dot-separated path."""
    parts = dotpath.split(".")
    obj = data
    for p in parts:
        if isinstance(obj, dict) and p in obj:
            obj = obj[p]
        else:
            return None
    return obj


def list_themes(themes_dir):
    """List all themes as JSON array with meta info."""
    themes = []
    for fname in sorted(os.listdir(themes_dir)):
        if not fname.endswith(".toml"):
            continue
        path = os.path.join(themes_dir, fname)
        try:
            data = read_toml(path)
            theme_id = fname[:-5]  # strip .toml
            meta = data.get("meta", {})
            entry = {
                "id": theme_id,
                "name": meta.get("name", theme_id.title()),
                "description": meta.get("description", ""),
                "icon": meta.get("icon", "󰏘"),
                "preview_image": meta.get("preview_image", ""),
                "file": fname,
            }
            # Include key settings for preview
            matugen = data.get("matugen", {})
            entry["scheme_type"] = matugen.get("scheme_type", "scheme-tonal-spot")
            appearance = data.get("appearance", {})
            entry["border_radius"] = appearance.get("border_radius", 12)
            entry["gaps_out"] = appearance.get("gaps_out", 10)
            themes.append(entry)
        except Exception:
            continue
    return themes


def main():
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        sys.exit(1)

    if sys.argv[1] == "--list":
        themes_dir = sys.argv[2] if len(sys.argv) > 2 else os.path.expanduser("~/.config/kingstra/themes")
        print(json.dumps(list_themes(themes_dir)))
        sys.exit(0)

    if sys.argv[1] == "--json":
        if len(sys.argv) < 3:
            print("Usage: kingstra-theme-read --json <file.toml>", file=sys.stderr)
            sys.exit(1)
        data = read_toml(sys.argv[2])
        print(json.dumps(data))
        sys.exit(0)

    # Read a single file
    toml_path = sys.argv[1]
    if not os.path.isfile(toml_path):
        print(f"File not found: {toml_path}", file=sys.stderr)
        sys.exit(1)

    data = read_toml(toml_path)

    if len(sys.argv) >= 3:
        # Get single value
        val = get_value(data, sys.argv[2])
        if val is None:
            sys.exit(1)
        print(val)
    else:
        # Print all as shell vars
        print_shell_vars(data)


if __name__ == "__main__":
    main()
