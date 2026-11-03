#!/usr/bin/env bash
# Smoke test voor kingstra-aur-cache: weg met downloads, oude builds en
# mappen van verwijderde pakketten; recept en de nieuwste builds blijven.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/config/shared/scripts/kingstra-aur-cache"
T="$(mktemp -d)"
trap 'rm -rf -- "$T"' EXIT
fail() { echo "FOUT: $*" >&2; exit 1; }

mkdir -p "$T/bin" "$T/yay"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" foo-bin bar-plugin\n' > "$T/bin/pacman"
chmod +x "$T/bin/pacman"

# foo-bin: geïnstalleerd, vier builds, een oude download en een bouwmap.
d="$T/yay/foo-bin"
mkdir -p "$d/src"
git -C "$d" init -q
printf 'pkgbase = foo-bin\n\tpkgname = foo-bin\n' > "$d/.SRCINFO"
printf 'pkgname=foo-bin\n' > "$d/PKGBUILD"
git -C "$d" add .SRCINFO PKGBUILD
for v in 1 2 3 4; do
    touch -d "2026-01-0$v" "$d/foo-bin-$v-1-x86_64.pkg.tar.zst"
done
touch "$d/foo-bin-1-1-x86_64.pkg.tar.zst.sig" "$d/foo_4_amd64.deb" "$d/src/bestand"
# Go zet zijn modulecache alleen-lezen.
mkdir -p "$d/src/go/mod"
touch "$d/src/go/mod/x.go"
chmod -R a-w "$d/src/go"

# bar: splitpakket waarvan alleen bar-plugin erop staat; baz is weg.
mkdir -p "$T/yay/bar" "$T/yay/baz"
printf 'pkgbase = bar\n\tpkgname = bar\n\tpkgname = bar-plugin\n' > "$T/yay/bar/.SRCINFO"
touch "$T/yay/baz/baz-1-1-any.pkg.tar.zst"
touch "$T/yay/vcs.json"

run() { PATH="$T/bin:$PATH" KINGSTRA_YAY_CACHE="$T/yay" bash "$SCRIPT" "$@"; }

out="$(run)"
grep -q 'niet meer geïnstalleerd.*baz' <<<"$out" || fail "baz hoort weg te kunnen"
grep -q 'bar$' <<<"$out" && fail "bar is via bar-plugin nog in gebruik"
[[ -e "$T/yay/baz" ]] || fail "zonder --clean mag niets weg"

run --clean >/dev/null
[[ ! -e "$T/yay/baz" ]] || fail "baz staat er nog"
[[ -d "$T/yay/bar" && -f "$T/yay/vcs.json" ]] || fail "bar of vcs.json is weggegooid"
[[ ! -e "$d/foo_4_amd64.deb" && ! -e "$d/src" ]] || fail "download/bouwmap staat er nog"
[[ -f "$d/PKGBUILD" && -f "$d/.SRCINFO" && -d "$d/.git" ]] || fail "recept is weggegooid"
[[ ! -e "$d/foo-bin-1-1-x86_64.pkg.tar.zst" && ! -e "$d/foo-bin-1-1-x86_64.pkg.tar.zst.sig" ]] \
    || fail "oudste build (met .sig) staat er nog"
for v in 2 3 4; do
    [[ -f "$d/foo-bin-$v-1-x86_64.pkg.tar.zst" ]] || fail "build $v hoort te blijven"
done
[[ "$(run --size)" == 0B ]] || fail "na opruimen hoort er niets meer over te zijn"

# Zonder pacman-uitvoer niets aanraken.
printf '#!/usr/bin/env bash\nexit 0\n' > "$T/bin/pacman"
mkdir -p "$T/yay/qux"
run --clean >/dev/null 2>&1 && fail "zonder pacman-lijst hoort het te weigeren"
[[ -d "$T/yay/qux" ]] || fail "qux is weggegooid zonder pacman-lijst"

echo "aur-cache: ok"
