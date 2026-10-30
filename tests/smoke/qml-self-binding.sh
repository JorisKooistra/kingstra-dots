#!/usr/bin/env bash
# Vangt bindingen als "mocha: mocha" binnen een Component { } (of een
# delegate): daar wint de eigen property van het object van een id met
# dezelfde naam, dus de property bindt aan zichzelf en wordt undefined.
# (2026-10: de schermvullende speler in een Loader kreeg zo geen kleuren en
# werd zwart-wit.) Buiten een Component lost Qt de id wel op.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
python3 - "$ROOT/config" <<'PY'
import os, re, sys
root = sys.argv[1]
bad = []
self_bind = re.compile(r'^\s*([a-z][A-Za-z0-9_]*)\s*:\s*\1\s*;?\s*$')
id_decl = re.compile(r'\bid\s*:\s*([a-z][A-Za-z0-9_]*)')
opener = re.compile(r'^\s*(Component|delegate\s*:\s*[A-Z][A-Za-z0-9_.]*)\s*\{')
for dirpath, _, files in os.walk(root):
    for name in files:
        if not name.endswith('.qml'):
            continue
        path = os.path.join(dirpath, name)
        rel = os.path.relpath(path, os.path.dirname(root))
        depth, stack = 0, []  # per Component: [startdiepte, ids, kandidaten]
        for no, line in enumerate(open(path, encoding='utf-8', errors='replace'), 1):
            code = line.split('//', 1)[0]
            if opener.match(code):
                stack.append([depth, set(), []])
            if stack:
                for m in id_decl.finditer(code):
                    stack[-1][1].add(m.group(1))
                m = self_bind.match(code)
                if m:
                    stack[-1][2].append((no, m.group(1), code.strip()))
            depth += code.count('{') - code.count('}')
            while stack and depth <= stack[-1][0]:
                start, ids, cands = stack.pop()
                # Een id binnen dezelfde Component wint wel; een id van
                # buiten de Component niet.
                for no2, nm, txt in cands:
                    if nm not in ids:
                        bad.append(f"FOUT: {rel}:{no2}: {txt} (bindt aan zichzelf: de id staat buiten deze Component; geef de id een andere naam)")
if bad:
    print("\n".join(bad))
    sys.exit(1)
print("ok: geen property bindt aan zichzelf binnen een Component")
PY
