#!/usr/bin/env python3
import configparser
import json
import os
import re
import shutil
import sqlite3
import sys
from pathlib import Path


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
                if child.is_dir() and (child / "global-messages-db.sqlite").exists() and child not in profiles:
                    profiles.append(child)

    return profiles


def table_columns(conn: sqlite3.Connection, table: str) -> list[str]:
    return [str(row[1]) for row in conn.execute(f'PRAGMA table_info("{table}")')]


def first_existing(columns: list[str], candidates: list[str]) -> str | None:
    by_lower = {c.lower(): c for c in columns}
    for candidate in candidates:
        if candidate.lower() in by_lower:
            return by_lower[candidate.lower()]
    return None


def parse_json_attributes(value: object) -> dict:
    if not isinstance(value, str) or not value:
        return {}
    try:
        parsed = json.loads(value)
        return parsed if isinstance(parsed, dict) else {}
    except json.JSONDecodeError:
        return {}


def sqlite_status(profile: Path) -> tuple[int | None, list[dict]]:
    db = profile / "global-messages-db.sqlite"
    if not db.exists():
        return None, []

    uri = db.as_uri() + "?mode=ro&immutable=1"
    conn = sqlite3.connect(uri, uri=True, timeout=0.25)
    conn.row_factory = sqlite3.Row
    try:
        cols = table_columns(conn, "messages")
        if not cols:
            return None, []

        unread_col = first_existing(cols, ["unread", "isUnread"])
        read_col = first_existing(cols, ["read", "isRead"])
        title_col = first_existing(cols, ["subject", "title"])
        sender_col = first_existing(cols, ["author", "sender", "from"])
        date_col = first_existing(cols, ["date", "timestamp", "time"])
        json_col = first_existing(cols, ["jsonAttributes", "attributes"])
        deleted_col = first_existing(cols, ["deleted"])

        where = ""
        if deleted_col:
            where = f' where coalesce("{deleted_col}", 0) = 0'

        unread: int | None = None
        if unread_col:
            unread = int(conn.execute(
                f'select count(*) from messages{where} and coalesce("{unread_col}", 0) != 0'
                if where else
                f'select count(*) from messages where coalesce("{unread_col}", 0) != 0'
            ).fetchone()[0])
        elif read_col:
            unread = int(conn.execute(
                f'select count(*) from messages{where} and coalesce("{read_col}", 0) = 0'
                if where else
                f'select count(*) from messages where coalesce("{read_col}", 0) = 0'
            ).fetchone()[0])

        recent: list[dict] = []
        text_cols = table_columns(conn, "messagesText_content")
        if {"docid", "c1subject", "c3author"}.issubset(set(text_cols)):
            order = f' order by m."{date_col}" desc' if date_col else " order by m.rowid desc"
            rows = conn.execute(
                "select t.c1subject as title, t.c3author as sender "
                "from messages m left join messagesText_content t on t.docid = m.id"
                f"{where.replace('where', ' where', 1) if where else ''}{order} limit 8"
            ).fetchall()
            for row in rows:
                recent.append({
                    "title": str(row["title"] or "").strip() or "Bericht",
                    "sender": str(row["sender"] or "").replace(" undefined", "").strip(),
                })
        else:
            select_cols = ["rowid"]
            for col in [title_col, sender_col, date_col, json_col]:
                if col and col not in select_cols:
                    select_cols.append(col)
            order = f' order by "{date_col}" desc' if date_col else " order by rowid desc"
            quoted = ", ".join([f'"{c}"' if c != "rowid" else c for c in select_cols])
            rows = conn.execute(f"select {quoted} from messages{where}{order} limit 8").fetchall()

            for row in rows:
                attrs = parse_json_attributes(row[json_col]) if json_col else {}
                title = str(row[title_col] or "") if title_col and row[title_col] is not None else ""
                sender = str(row[sender_col] or "") if sender_col and row[sender_col] is not None else ""
                if not title:
                    title = str(attrs.get("subject") or attrs.get("title") or "")
                if not sender:
                    sender = str(attrs.get("author") or attrs.get("sender") or attrs.get("from") or "")
                recent.append({
                    "title": title or "Bericht",
                    "sender": sender,
                })

        if unread is None and json_col:
            read_attr_id = None
            try:
                attr_row = conn.execute(
                    "select id from attributeDefinitions where name = 'read' limit 1"
                ).fetchone()
                if attr_row:
                    read_attr_id = str(attr_row[0])
            except sqlite3.Error:
                read_attr_id = None

            json_unread = 0
            json_seen = 0
            for row in conn.execute(f'select "{json_col}" from messages{where}'):
                attrs = parse_json_attributes(row[0])
                if not attrs:
                    continue
                if read_attr_id and read_attr_id in attrs:
                    json_seen += 1
                    json_unread += 0 if attrs.get(read_attr_id) else 1
                elif "unread" in attrs:
                    json_seen += 1
                    json_unread += 1 if attrs.get("unread") else 0
                elif "read" in attrs:
                    json_seen += 1
                    json_unread += 0 if attrs.get("read") else 1
                elif "isRead" in attrs:
                    json_seen += 1
                    json_unread += 0 if attrs.get("isRead") else 1
            if json_seen > 0:
                unread = json_unread

        return unread, recent
    finally:
        conn.close()


def msf_unread(profile: Path) -> int | None:
    total = 0
    seen = False
    for root_name in ("ImapMail", "Mail"):
        root = profile / root_name
        if not root.exists():
            continue
        for msf in root.rglob("*.msf"):
            try:
                text = msf.read_text(errors="ignore")
            except OSError:
                continue
            matches = re.findall(r"numUnread(?:Messages)?[^\d]{0,24}(\d+)", text, re.IGNORECASE)
            for match in matches[:1]:
                seen = True
                total += int(match)
    return total if seen else None


def main() -> int:
    profiles = profile_dirs()
    unread_total = 0
    unread_known = False
    recent: list[dict] = []

    for profile in profiles:
        try:
            unread, items = sqlite_status(profile)
        except (OSError, sqlite3.Error):
            unread, items = None, []
        if unread is None:
            unread = msf_unread(profile)
        if unread is not None:
            unread_known = True
            unread_total += max(0, int(unread))
        recent.extend(items)

    available = shutil.which("thunderbird") is not None
    result = {
        "available": available,
        "running": thunderbird_running(),
        "profileFound": len(profiles) > 0,
        "unreadKnown": unread_known,
        "unread": unread_total if unread_known else 0,
        "recent": recent[:6],
    }
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
