#!/usr/bin/env python3
"""Emoji zoeken voor de launcher (voorvoegsel ":").

Gebruikt de Unicode-namen uit de standaardbibliotheek, dus er is geen
losse emojilijst nodig. Een paar Nederlandse woorden worden vertaald naar
het Engelse woord in de Unicode-naam. Uitvoer: JSON-lijst van
{"char": "...", "name": "..."}, hooguit 40 treffers.
"""
import json
import sys
import unicodedata

RANGES = [
    (0x1F300, 0x1F5FF), (0x1F600, 0x1F64F), (0x1F680, 0x1F6FF),
    (0x1F900, 0x1F9FF), (0x1FA70, 0x1FAFF), (0x2600, 0x26FF), (0x2700, 0x27BF),
]

NL = {
    "lach": "smil", "blij": "grin", "hart": "heart", "duim": "thumbs",
    "vuur": "fire", "ster": "star", "kat": "cat", "hond": "dog", "zon": "sun",
    "maan": "moon", "regen": "rain", "sneeuw": "snow", "huil": "cry",
    "boos": "angry", "verdrietig": "sad", "kus": "kiss", "feest": "party",
    "taart": "cake", "koffie": "coffee", "bier": "beer", "wijn": "wine",
    "auto": "car", "fiets": "bicycle", "huis": "house", "boom": "tree",
    "bloem": "flower", "vis": "fish", "vogel": "bird", "klok": "clock",
    "geld": "money", "boek": "book", "muziek": "music", "denk": "think",
    "ogen": "eyes", "oog": "eye", "hand": "hand", "klap": "clap",
    "spier": "biceps", "raket": "rocket", "vlag": "flag", "check": "check",
    "kruis": "cross", "waarschuwing": "warning", "slot": "lock",
}


def main() -> None:
    query = " ".join(sys.argv[1:]).strip().lower()
    words = [NL.get(w, w) for w in query.split()]
    out = []
    for start, end in RANGES:
        for code in range(start, end + 1):
            char = chr(code)
            name = unicodedata.name(char, "").lower()
            if not name:
                continue
            if all(w in name for w in words):
                out.append({"char": char, "name": name})
                if len(out) >= 40:
                    print(json.dumps(out, ensure_ascii=False))
                    return
    print(json.dumps(out, ensure_ascii=False))


if __name__ == "__main__":
    main()
