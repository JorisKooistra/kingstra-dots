#!/usr/bin/env python3
import configparser
import json
import os
import re
import shutil
import sqlite3
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from zoneinfo import ZoneInfo


EVENT_LIMIT = 80


def profile_dirs() -> list[Path]:
    home = Path.home()
    roots = [home / ".thunderbird", home / ".mozilla-thunderbird"]
    profiles: list[Path] = []

    for root in roots:
        ini = root / "profiles.ini"
        if ini.exists():
            parser = configparser.ConfigParser()
            try:
                parser.read(ini)
            except configparser.Error:
                parser = configparser.ConfigParser()
            for section in parser.sections():
                if not section.lower().startswith("profile"):
                    continue
                raw_path = parser.get(section, "Path", fallback="")
                if not raw_path:
                    continue
                is_relative = parser.get(section, "IsRelative", fallback="1") != "0"
                path = root / raw_path if is_relative else Path(raw_path)
                if path.exists() and path not in profiles:
                    profiles.append(path)

        if root.exists():
            for child in root.iterdir():
                if child.is_dir() and (child / "prefs.js").exists() and child not in profiles:
                    profiles.append(child)

    return profiles


def pref_value(raw: str):
    raw = raw.strip()
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        if raw.lower() == "true":
            return True
        if raw.lower() == "false":
            return False
        return raw.strip('"')


def read_prefs(profile: Path) -> dict:
    prefs = profile / "prefs.js"
    if not prefs.exists():
        return {}

    out = {}
    try:
        lines = prefs.read_text(errors="ignore").splitlines()
    except OSError:
        return out

    for line in lines:
        match = re.match(r'user_pref\("([^"]+)",\s*(.+)\);', line.strip())
        if not match:
            continue
        out[match.group(1)] = pref_value(match.group(2))
    return out


def calendar_registry(profile: Path) -> list[dict]:
    prefs = read_prefs(profile)
    sort_order = str(prefs.get("calendar.list.sortOrder", "") or "").split()
    calendars: dict[str, dict] = {}

    prefix = "calendar.registry."
    for key, value in prefs.items():
        if not key.startswith(prefix):
            continue
        rest = key[len(prefix):]
        parts = rest.split(".", 1)
        if len(parts) != 2:
            continue
        cal_id, field = parts
        item = calendars.setdefault(cal_id, {"id": cal_id})
        item[field] = value

    def sort_key(item: dict):
        try:
            return sort_order.index(item["id"])
        except ValueError:
            return len(sort_order)

    result = []
    for item in sorted(calendars.values(), key=sort_key):
        if bool(item.get("disabled", False)):
            continue
        result.append({
            "id": str(item.get("id", "")),
            "name": str(item.get("name") or "Kalender"),
            "color": str(item.get("color") or "#89b4fa"),
            "type": str(item.get("type") or ""),
            "uri": str(item.get("uri") or ""),
            "username": str(item.get("username") or ""),
            "readOnly": bool(item.get("readOnly", False)),
        })
    return result


def choose_profile(profiles: list[Path]) -> Path | None:
    if not profiles:
        return None
    scored = []
    for index, profile in enumerate(profiles):
        calendars = calendar_registry(profile)
        has_db = (profile / "calendar-data" / "local.sqlite").exists()
        scored.append((len(calendars), 1 if has_db else 0, -index, profile))
    scored.sort(reverse=True)
    return scored[0][3]


def thunderbird_running() -> bool:
    proc = Path("/proc")
    for entry in proc.iterdir() if proc.exists() else []:
        if not entry.name.isdigit():
            continue
        try:
            comm = (entry / "comm").read_text(errors="ignore").strip().lower()
            if "thunderbird" in comm:
                return True
            cmdline = (entry / "cmdline").read_text(errors="ignore").replace("\x00", " ").lower()
            if "thunderbird" in cmdline:
                return True
        except OSError:
            continue
    return False


def local_dt(value: int | None, tz_name: str | None, local_tz: ZoneInfo) -> datetime | None:
    if value is None:
        return None
    try:
        raw = int(value)
    except (TypeError, ValueError):
        return None

    if raw > 10_000_000_000_000:
        seconds = raw / 1_000_000
    elif raw > 10_000_000_000:
        seconds = raw / 1000
    else:
        seconds = raw

    tz_text = str(tz_name or "")
    if tz_text.upper() == "UTC":
        return datetime.fromtimestamp(seconds, timezone.utc).astimezone(local_tz)
    if tz_text and tz_text.upper() != "FLOATING":
        try:
            tz = ZoneInfo(tz_text)
            return datetime.fromtimestamp(seconds, tz).astimezone(local_tz)
        except Exception:
            pass
    return datetime.fromtimestamp(seconds, local_tz)


def read_events(profile: Path, calendars: list[dict]) -> list[dict]:
    db = profile / "calendar-data" / "local.sqlite"
    if not db.exists():
        return []

    cal_by_id = {c["id"]: c for c in calendars}
    local_tz = ZoneInfo(os.environ.get("TZ") or "Europe/Amsterdam")
    now = datetime.now(local_tz)
    horizon = now.timestamp() + 60 * 60 * 24 * 45

    tmp_path = ""
    try:
        with tempfile.NamedTemporaryFile(prefix="tb-calendar-", suffix=".sqlite", delete=False) as tmp:
            tmp_path = tmp.name
        shutil.copyfile(db, tmp_path)
        conn = sqlite3.connect(tmp_path, timeout=0.25)
        conn.row_factory = sqlite3.Row
        rows = conn.execute(
            """
            SELECT cal_id, id, title, ical_status, event_start, event_end,
                   event_start_tz, event_end_tz
            FROM cal_events
            WHERE event_start IS NOT NULL
              AND (ical_status IS NULL OR ical_status != 'CANCELLED')
            ORDER BY event_start
            LIMIT 500
            """
        ).fetchall()
        conn.close()
    except (OSError, sqlite3.Error):
        return []
    finally:
        if tmp_path:
            try:
                os.unlink(tmp_path)
            except OSError:
                pass

    events: list[dict] = []
    for row in rows:
        start = local_dt(row["event_start"], row["event_start_tz"], local_tz)
        end = local_dt(row["event_end"], row["event_end_tz"], local_tz)
        if not start:
            continue
        if start.timestamp() < now.timestamp() - 60 * 60 * 12:
            continue
        if start.timestamp() > horizon:
            continue

        cal = cal_by_id.get(str(row["cal_id"]), {})
        all_day = start.hour == 0 and start.minute == 0 and end and end.hour == 0 and end.minute == 0
        events.append({
            "id": str(row["id"] or ""),
            "calendarId": str(row["cal_id"] or ""),
            "calendar": str(cal.get("name") or "Kalender"),
            "color": str(cal.get("color") or "#89b4fa"),
            "title": str(row["title"] or "(Geen titel)"),
            "start": start.isoformat(),
            "end": end.isoformat() if end else "",
            "dateKey": start.strftime("%Y-%m-%d"),
            "day": start.strftime("%a %d %b"),
            "time": "Hele dag" if all_day else start.strftime("%H:%M"),
            "allDay": bool(all_day),
        })
        if len(events) >= EVENT_LIMIT:
            break
    return events


def main() -> int:
    profiles = profile_dirs()
    profile = choose_profile(profiles)
    calendars = calendar_registry(profile) if profile else []
    events = read_events(profile, calendars) if profile else []
    payload = {
        "available": shutil.which("thunderbird") is not None,
        "running": thunderbird_running(),
        "profileFound": profile is not None,
        "profile": str(profile or ""),
        "calendars": calendars,
        "events": events,
        "eventCount": len(events),
    }
    json.dump(payload, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
