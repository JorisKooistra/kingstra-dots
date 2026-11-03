#!/usr/bin/env python3
"""Wat een update zou doen, als JSON voor de Updates-pagina in Instellingen.

Installeert niets en vraagt geen wachtwoord. Schrijft ook naar
~/.cache/kingstra/update-plan.json, zodat de pagina meteen iets kan tonen.

Groepen: Systeem en kernel (pakketten die het vermelden waard zijn), Apps
(overige Arch-pakketten), AUR, Flatpak en Kingstra (nieuwe commits plus de
nieuwe CHANGELOG-regels in gewone taal). Daarnaast Arch-nieuws sinds de
vorige update en hoeveel pakketten al gedownload zijn.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.request
from email.utils import parsedate_to_datetime
from pathlib import Path

HOME = Path.home()
CACHE = Path(os.environ.get("XDG_CACHE_HOME", HOME / ".cache")) / "kingstra" / "update-plan.json"
STATE = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state")) / "kingstra"
LAST_RUN = STATE / "updates" / "last-run"
PKG_CACHE = Path("/var/cache/pacman/pkg")
NEWS_URL = "https://archlinux.org/feeds/news/"
NOTABLE = re.compile(r"^(linux(-lts|-zen|-hardened)?|linux-firmware|nvidia\S*|mesa|vulkan-\S+|systemd|glibc|"
                     r"hyprland|hyprlock|hypridle|quickshell\S*|pipewire|wireplumber|sddm|networkmanager|"
                     r"bluez|grub|mkinitcpio)$")


def run(cmd, timeout=90, cwd=None):
    if shutil.which(cmd[0]) is None:
        return ""
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, cwd=cwd).stdout
    except (subprocess.SubprocessError, OSError):
        return ""


def pkg_lines(text):
    out = []
    for line in text.splitlines():
        parts = line.split()
        if len(parts) >= 4 and parts[2] == "->":
            out.append({"name": parts[0], "from": parts[1], "to": parts[3]})
    return out


def downloaded(pkg):
    return any(PKG_CACHE.glob(f"{pkg['name']}-{pkg['to']}-*.pkg.tar.*"))


def repo_dir():
    marker = HOME / ".local/share/kingstra/install-complete"
    try:
        for line in marker.read_text().splitlines():
            if line.startswith("Repo:"):
                return Path(line.split(":", 1)[1].strip())
    except OSError:
        pass
    return Path(__file__).resolve().parents[2]


def kingstra_changes():
    repo = repo_dir()
    if not (repo / ".git").exists():
        return [], []
    if (STATE / "update-hold").exists():
        return [{"name": "Dotfiles staan vast na een rollback (kingstra rollback --release)"}], []
    run(["git", "-C", str(repo), "fetch", "--quiet", "origin"], timeout=30)
    upstream = run(["git", "-C", str(repo), "rev-parse", "--abbrev-ref", "@{upstream}"]).strip() or "origin/main"
    log = run(["git", "-C", str(repo), "log", "--format=%s", f"HEAD..{upstream}"]).splitlines()
    diff = run(["git", "-C", str(repo), "diff", f"HEAD...{upstream}", "--", "CHANGELOG.md"])
    notes = []
    for line in diff.splitlines():
        if line.startswith("+- ") or line.startswith("+  - "):
            text = re.sub(r"\*\*(.+?)\*\*", r"\1", line[1:].strip()[2:])
            text = re.sub(r"`([^`]+)`", r"\1", text)
            notes.append(text if len(text) < 220 else text[:217].rstrip() + "…")
    return [{"name": s} for s in log if s.strip()], notes[:30]


def arch_news():
    try:
        last = int(LAST_RUN.read_text().strip())
    except (OSError, ValueError):
        last = 0
    try:
        with urllib.request.urlopen(NEWS_URL, timeout=8) as fh:
            feed = fh.read().decode("utf-8", "replace")
    except Exception:
        return []
    items = []
    for block in re.findall(r"<item>(.*?)</item>", feed, re.S):
        title = re.search(r"<title>(.*?)</title>", block, re.S)
        pub = re.search(r"<pubDate>(.*?)</pubDate>", block, re.S)
        if not title or not pub:
            continue
        try:
            ts = int(parsedate_to_datetime(pub.group(1)).timestamp())
        except (TypeError, ValueError):
            continue
        if last and ts <= last:
            break
        items.append({"date": time.strftime("%d-%m-%Y", time.localtime(ts)),
                      "title": title.group(1).replace("&amp;", "&").replace("&quot;", '"').replace("&#39;", "'")})
        if not last and len(items) >= 3:
            break
    return items


def main():
    repo = pkg_lines(run(["checkupdates"]))
    helper = "yay" if shutil.which("yay") else ("paru" if shutil.which("paru") else "")
    aur = pkg_lines(run([helper, "-Qua"])) if helper else []
    flatpak = []
    for line in run(["flatpak", "remote-ls", "--updates", "--columns=application,version"]).splitlines():
        parts = line.split()
        if parts:
            flatpak.append({"name": parts[0], "from": "", "to": parts[1] if len(parts) > 1 else ""})
    for pkg in repo:
        pkg["downloaded"] = downloaded(pkg)
    system = [p for p in repo if NOTABLE.match(p["name"])]
    apps = [p for p in repo if not NOTABLE.match(p["name"])]
    commits, notes = kingstra_changes()

    plan = {
        "checked": int(time.time()),
        "total": len(repo) + len(aur) + len(flatpak) + (1 if commits else 0),
        "downloaded": sum(1 for p in repo if p["downloaded"]),
        "repo": len(repo),
        "kernel": any(re.match(r"^linux(-lts|-zen|-hardened)?$", p["name"]) for p in repo),
        "news": arch_news(),
        "groups": [
            {"id": "systeem", "title": "Systeem en kernel", "items": system},
            {"id": "apps", "title": "Apps en bibliotheken", "items": apps},
            {"id": "aur", "title": "AUR", "items": aur},
            {"id": "flatpak", "title": "Flatpak", "items": flatpak},
            {"id": "kingstra", "title": "Kingstra", "items": commits, "notes": notes},
        ],
    }
    text = json.dumps(plan, ensure_ascii=False)
    try:
        CACHE.parent.mkdir(parents=True, exist_ok=True)
        tmp = CACHE.with_suffix(".tmp")
        tmp.write_text(text)
        tmp.replace(CACHE)
    except OSError:
        pass
    print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
