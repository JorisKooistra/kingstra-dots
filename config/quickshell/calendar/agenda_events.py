#!/usr/bin/env python3
import json
import os
import sys
import tempfile
import time
import uuid
from datetime import datetime, timedelta
from pathlib import Path


def state_path() -> Path:
    state_home = os.environ.get("XDG_STATE_HOME") or str(Path.home() / ".local/state")
    return Path(state_home) / "kingstra" / "local-agenda-events.json"


def load_events() -> list[dict]:
    path = state_path()
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        data = {}
    events = data.get("events", []) if isinstance(data, dict) else []
    return [event for event in events if isinstance(event, dict)]


def save_events(events: list[dict]) -> None:
    path = state_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".local-agenda-", dir=path.parent, text=True)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump({"version": 1, "events": events}, fh, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
            fh.write("\n")
        os.chmod(tmp, 0o600)
        os.replace(tmp, path)
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def valid_date(value: str) -> str:
    dt = datetime.strptime(value, "%Y-%m-%d")
    return dt.strftime("%Y-%m-%d")


def valid_time(value: str) -> str:
    text = (value or "").strip()
    if text == "":
        return ""
    dt = datetime.strptime(text, "%H:%M")
    return dt.strftime("%H:%M")


def day_label(date_key: str) -> str:
    return datetime.strptime(date_key, "%Y-%m-%d").strftime("%a %d %b")


def normalize_event(event: dict) -> dict:
    date_key = valid_date(str(event.get("dateKey") or event.get("date") or ""))
    time_text = valid_time(str(event.get("timeRaw") or event.get("time") or ""))
    title = " ".join(str(event.get("title") or "").split()).strip()
    if not title:
        title = "(Geen titel)"
    return {
        "id": str(event.get("id") or uuid.uuid4()),
        "calendarId": "kingstra-local",
        "calendar": "Lokaal",
        "color": "accent3",
        "title": title,
        "dateKey": date_key,
        "day": day_label(date_key),
        "time": time_text or "Hele dag",
        "timeRaw": time_text,
        "allDay": time_text == "",
        "source": "local",
        "createdAt": int(event.get("createdAt") or time.time()),
    }


def event_sort_key(event: dict):
    return (
        str(event.get("dateKey") or ""),
        str(event.get("timeRaw") or "99:99"),
        str(event.get("title") or "").lower(),
    )


def filtered_events(events: list[dict]) -> list[dict]:
    today = datetime.now().date()
    oldest = today - timedelta(days=1)
    newest = today + timedelta(days=370)
    out = []
    for event in events:
        try:
            normalized = normalize_event(event)
            date = datetime.strptime(normalized["dateKey"], "%Y-%m-%d").date()
        except ValueError:
            continue
        if oldest <= date <= newest:
            out.append(normalized)
    out.sort(key=event_sort_key)
    return out


def print_payload(events: list[dict]) -> None:
    visible = filtered_events(events)
    json.dump({"events": visible, "eventCount": len(visible)}, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")


def main() -> int:
    action = sys.argv[1] if len(sys.argv) > 1 else "list"
    events = load_events()

    if action == "list":
        print_payload(events)
        return 0

    if action == "add":
        if len(sys.argv) < 6:
            return 2
        _, _, _unused_id, date_key, time_text, title = sys.argv[:6]
        try:
            event = normalize_event({
                "id": str(uuid.uuid4()),
                "dateKey": date_key,
                "timeRaw": time_text,
                "title": title,
                "createdAt": int(time.time()),
            })
        except ValueError:
            return 2
        events.append(event)
        save_events(filtered_events(events))
        print_payload(events)
        return 0

    if action == "delete":
        if len(sys.argv) < 3:
            return 2
        event_id = sys.argv[2]
        events = [event for event in events if str(event.get("id") or "") != event_id]
        save_events(filtered_events(events))
        print_payload(events)
        return 0

    return 2


if __name__ == "__main__":
    raise SystemExit(main())
