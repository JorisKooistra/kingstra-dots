#!/usr/bin/env python3
import configparser
from collections import Counter
from email.utils import getaddresses
import json
import os
import re
import shutil
import sqlite3
import sys
from pathlib import Path


RECENT_LIMIT = 48
EMAIL_RE = re.compile(r"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}", re.IGNORECASE)


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


def pref_value(line: str, key: str) -> str | None:
    prefix = f'user_pref("{key}", '
    if not line.startswith(prefix) or not line.rstrip().endswith(");"):
        return None
    raw = line[len(prefix):-3].strip()
    try:
        parsed = json.loads(raw)
        return parsed if isinstance(parsed, str) else None
    except json.JSONDecodeError:
        return raw.strip('"')


def clean_header(value: object) -> str:
    text = str(value or "")
    text = re.sub(r"\bundefined\b", "", text, flags=re.IGNORECASE)
    return re.sub(r"\s+", " ", text).strip(" ,;")


def extract_emails(value: object) -> list[str]:
    text = clean_header(value)
    found: list[str] = []
    for _, address in getaddresses([text]):
        if EMAIL_RE.fullmatch(address or ""):
            found.append(address)
    found.extend(EMAIL_RE.findall(text))

    unique: list[str] = []
    seen: set[str] = set()
    for address in found:
        key = address.lower()
        if key in seen:
            continue
        seen.add(key)
        unique.append(address)
    return unique


def profile_accounts(profile: Path) -> list[dict]:
    prefs = profile / "prefs.js"
    if not prefs.exists():
        return []

    identity_emails: dict[str, str] = {}
    identity_names: dict[str, str] = {}
    account_identity_order: list[str] = []
    server_usernames: list[str] = []

    try:
        lines = prefs.read_text(errors="ignore").splitlines()
    except OSError:
        return []

    for line in lines:
        identity_match = re.match(
            r'user_pref\("mail\.identity\.([^".]+)\.(useremail|fullName)",\s*(.+)\);',
            line,
        )
        if identity_match:
            identity_id, field = identity_match.group(1), identity_match.group(2)
            value = pref_value(line, f"mail.identity.{identity_id}.{field}")
            if not value:
                continue
            if field == "useremail":
                emails = extract_emails(value)
                if emails:
                    identity_emails[identity_id] = emails[0]
            elif field == "fullName":
                identity_names[identity_id] = clean_header(value)
            continue

        account_match = re.match(r'user_pref\("mail\.account\.[^".]+\.identities",\s*(.+)\);', line)
        if account_match:
            value = pref_value(line, re.search(r'"([^"]+)"', line).group(1))
            for identity_id in [part.strip() for part in str(value or "").split(",")]:
                if identity_id and identity_id not in account_identity_order:
                    account_identity_order.append(identity_id)
            continue

        server_match = re.match(r'user_pref\("mail\.server\.[^".]+\.userName",\s*(.+)\);', line)
        if server_match:
            value = pref_value(line, re.search(r'"([^"]+)"', line).group(1))
            for email in extract_emails(value):
                if email not in server_usernames:
                    server_usernames.append(email)

    ordered_ids = account_identity_order + [
        identity_id for identity_id in identity_emails.keys()
        if identity_id not in account_identity_order
    ]

    accounts: list[dict] = []
    seen: set[str] = set()
    for identity_id in ordered_ids:
        address = identity_emails.get(identity_id)
        if not address:
            continue
        key = address.lower()
        if key in seen:
            continue
        seen.add(key)
        accounts.append({
            "address": address,
            "label": address,
            "name": identity_names.get(identity_id, ""),
        })

    for address in server_usernames:
        key = address.lower()
        if key in seen:
            continue
        seen.add(key)
        accounts.append({"address": address, "label": address, "name": ""})

    return accounts


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


def safe_int(value: object) -> int:
    try:
        return int(value or 0)
    except (TypeError, ValueError):
        return 0


def display_recipient(recipients: list[str], known_accounts: dict[str, str], raw: object) -> tuple[str, str]:
    matched = [known_accounts[address.lower()] for address in recipients if address.lower() in known_accounts]
    preferred = matched if matched else recipients
    if not preferred:
        return clean_header(raw), ""

    label = ", ".join(preferred[:2])
    if len(preferred) > 2:
        label += f" +{len(preferred) - 2}"
    return label, preferred[0].lower()


def message_item(
    title: object,
    sender: object,
    recipients_raw: object,
    timestamp: object,
    known_accounts: dict[str, str] | None = None,
) -> dict:
    recipients = extract_emails(recipients_raw)
    recipient_label, account = display_recipient(recipients, known_accounts or {}, recipients_raw)
    return {
        "title": clean_header(title) or "Bericht",
        "sender": clean_header(sender),
        "recipient": recipient_label,
        "recipients": recipients,
        "account": account,
        "timestamp": safe_int(timestamp),
    }


def sqlite_status(profile: Path) -> tuple[int | None, list[dict]]:
    db = profile / "global-messages-db.sqlite"
    if not db.exists():
        return None, []

    uri = db.as_uri() + "?mode=ro&immutable=1"
    conn = sqlite3.connect(uri, uri=True, timeout=0.25)
    conn.row_factory = sqlite3.Row
    try:
        known_accounts = {
            str(account.get("address") or "").lower(): str(account.get("address") or "")
            for account in profile_accounts(profile)
            if str(account.get("address") or "")
        }
        cols = table_columns(conn, "messages")
        if not cols:
            return None, []

        unread_col = first_existing(cols, ["unread", "isUnread"])
        read_col = first_existing(cols, ["read", "isRead"])
        title_col = first_existing(cols, ["subject", "title"])
        sender_col = first_existing(cols, ["author", "sender", "from"])
        recipients_col = first_existing(cols, ["recipients", "recipient", "to", "cc"])
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
            recipients_select = "t.c4recipients" if "c4recipients" in text_cols else "''"
            timestamp_select = f'm."{date_col}"' if date_col else "m.rowid"
            rows = conn.execute(
                "select t.c1subject as title, t.c3author as sender, "
                f"{recipients_select} as recipients, "
                f"{timestamp_select} as timestamp "
                "from messages m left join messagesText_content t on t.docid = m.id"
                f"{where.replace('where', ' where', 1) if where else ''}{order} limit {RECENT_LIMIT}"
            ).fetchall()
            for row in rows:
                recent.append(
                    message_item(
                        row["title"],
                        row["sender"],
                        row["recipients"],
                        row["timestamp"],
                        known_accounts,
                    )
                )
        else:
            select_cols = ["rowid"]
            for col in [title_col, sender_col, recipients_col, date_col, json_col]:
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
                recipients = ""
                if recipients_col and row[recipients_col] is not None:
                    recipients = str(row[recipients_col] or "")
                if not recipients:
                    recipients = str(attrs.get("recipients") or attrs.get("recipient") or attrs.get("to") or "")
                timestamp = row[date_col] if date_col else row["rowid"]
                recent.append(message_item(title, sender, recipients, timestamp, known_accounts))

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


def account_filters(profiles: list[Path], recent: list[dict]) -> list[dict]:
    known: list[dict] = []
    seen_known: set[str] = set()
    for profile in profiles:
        for account in profile_accounts(profile):
            address = str(account.get("address") or "")
            key = address.lower()
            if not key or key in seen_known:
                continue
            seen_known.add(key)
            known.append(account)

    counts: Counter[str] = Counter()
    for item in recent:
        for address in item.get("recipients") or []:
            key = str(address).lower()
            if not key:
                continue
            counts[key] += 1

    filters: list[dict] = []
    for account in known:
        address = str(account.get("address") or "")
        key = address.lower()
        if not key:
            continue
        filters.append({
            "address": address,
            "label": address,
            "name": str(account.get("name") or ""),
            "count": int(counts.get(key, 0)),
            "known": True,
        })

    return filters


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

    recent.sort(key=lambda item: int(item.get("timestamp") or 0), reverse=True)
    recent = recent[:RECENT_LIMIT]
    filters = account_filters(profiles, recent)

    available = shutil.which("thunderbird") is not None
    result = {
        "available": available,
        "running": thunderbird_running(),
        "profileFound": len(profiles) > 0,
        "unreadKnown": unread_known,
        "unread": unread_total if unread_known else 0,
        "accounts": filters,
        "recent": recent,
    }
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
