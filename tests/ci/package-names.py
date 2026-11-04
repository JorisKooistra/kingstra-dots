#!/usr/bin/env python3
"""Alle pakketnamen die de installer kan installeren, als regels '<bron> <naam>'.

bron is repo of aur. Leest manifest/packages/*.txt en de letterlijke namen in
pacman_install/aur_install-aanroepen van installer/phases en installer/lib.
Namen met $ of andere shell-expansies slaan we over: die kan alleen een echte
run controleren.
"""
import pathlib
import re
import shlex
import sys

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
out = set()
for f in sorted((root / "manifest/packages").glob("*.txt")):
    for line in f.read_text().splitlines():
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        if line.startswith("aur:"):
            out.add(("aur", line[4:]))
        else:
            out.add(("repo", line))

call = re.compile(r"^\s*(pacman_install|pacman_install_optional|aur_install|aur_install_optional)\s+(.*)$")
for f in sorted(list((root / "installer/phases").glob("*.sh")) + list((root / "installer/lib").glob("*.sh"))):
    for line in f.read_text().splitlines():
        m = call.match(line)
        if not m:
            continue
        args = m.group(2).split("#", 1)[0]
        args = re.split(r"\s*(\|\||&&|;|\|)\s*", args)[0]
        try:
            words = shlex.split(args)
        except ValueError:
            continue
        src = "aur" if m.group(1).startswith("aur") else "repo"
        for w in words:
            if re.fullmatch(r"[a-z0-9@._+-]+", w) and not w.startswith("-"):
                out.add((src, w))

for src, name in sorted(out):
    print(src, name)
