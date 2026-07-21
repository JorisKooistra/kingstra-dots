#!/usr/bin/env python3
"""
list-apps.py — desktop entries als JSON voor de shell-launcher.

Quickshell's eigen DesktopEntries-API levert op dit systeem 0 resultaten,
daarom scannen we de XDG-applicatiemappen zelf. Output: JSON-array met
appmetadata, gesorteerd op naam en ontdubbeld op desktop-id.
"""
import json
import os
import re
import sys

FIELD_CODES = re.compile(r"%[fFuUdDnNickvm]")


def xdg_app_dirs():
    home = os.path.expanduser("~")
    data_home = os.environ.get("XDG_DATA_HOME") or os.path.join(home, ".local/share")
    data_dirs = os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
    roots = [data_home] + data_dirs.split(":")
    roots.append("/var/lib/flatpak/exports/share")
    roots.append(os.path.join(data_home, "flatpak/exports/share"))

    seen, out = set(), []
    for root in roots:
        d = os.path.join(os.path.expanduser(root.strip()), "applications")
        if d not in seen and os.path.isdir(d):
            seen.add(d)
            out.append(d)
    return out


def parse_entry(path):
    """Lees alleen de [Desktop Entry]-sectie; latere secties zijn acties."""
    data = {}
    in_section = False
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if line.startswith("["):
                    if in_section:
                        break
                    in_section = line == "[Desktop Entry]"
                    continue
                if not in_section or "=" not in line or line.startswith("#"):
                    continue
                key, _, value = line.partition("=")
                data.setdefault(key.strip(), value.strip())
    except OSError:
        return None

    if data.get("Type") != "Application":
        return None
    if data.get("NoDisplay", "").lower() == "true":
        return None
    if data.get("Hidden", "").lower() == "true":
        return None

    name = data.get("Name", "").strip()
    exec_raw = data.get("Exec", "").strip()
    if not name or not exec_raw:
        return None

    exec_clean = FIELD_CODES.sub("", exec_raw).strip()
    return {
        "id": os.path.basename(path),
        "name": name,
        "exec": exec_clean,
        "execString": exec_clean,
        "icon": data.get("Icon", "").strip(),
        "comment": data.get("Comment", "").strip(),
        "genericName": data.get("GenericName", "").strip(),
        "keywords": data.get("Keywords", "").strip(),
        "categories": data.get("Categories", "").strip(),
        "startupClass": data.get("StartupWMClass", "").strip(),
        "terminal": data.get("Terminal", "").lower() == "true",
    }


def main():
    apps, seen_ids = {}, set()
    for directory in xdg_app_dirs():
        for entry in sorted(os.listdir(directory)):
            if not entry.endswith(".desktop"):
                continue
            # Eerste vondst wint: XDG_DATA_HOME gaat voor /usr/share.
            if entry in seen_ids:
                continue
            parsed = parse_entry(os.path.join(directory, entry))
            if parsed:
                seen_ids.add(entry)
                apps[entry] = parsed

    result = sorted(apps.values(), key=lambda a: a["name"].lower())
    json.dump(result, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
