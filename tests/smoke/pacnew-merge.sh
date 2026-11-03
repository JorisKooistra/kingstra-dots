#!/usr/bin/env bash
# Smoke test voor kingstra-pacnew-merge: eigen regels blijven, nieuwe regels
# komen erbij, JSON en grote verschillen worden geweigerd.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
M="$REPO_ROOT/config/shared/scripts/kingstra-pacnew-merge"
T="$(mktemp -d)"
trap 'rm -rf -- "$T"' EXIT
fail() { echo "FOUT: $*" >&2; exit 1; }

# pam.d/sudo: vingerafdruk blijft vóór system-auth, pam_systemd komt erbij.
printf 'auth       sufficient   pam_fprintd.so\n#%%PAM-1.0\nauth\t\tinclude\t\tsystem-auth\nsession\t\tinclude\t\tsystem-auth\n' > "$T/sudo"
printf '#%%PAM-1.0\nauth\t\tinclude\t\tsystem-auth\nsession\t\tinclude\t\tsystem-auth\nsession\t\toptional\tpam_systemd.so class=none\n' > "$T/sudo.pacnew"
out="$(python3 "$M" "$T/sudo" "$T/sudo.pacnew")"
[[ "$(sed -n 2p <<<"$out")" == *pam_fprintd.so ]] || fail "pam_fprintd hoort direct na de kopregel: $out"
grep -q 'pam_systemd.so class=none' <<<"$out" || fail "nieuwe pam_systemd-regel ontbreekt"
[[ "$(grep -c pam_fprintd <<<"$out")" == 1 ]] || fail "pam_fprintd dubbel"

# locale.gen: eigen locales blijven aan, nieuwe regels erbij.
printf '#en_SG ISO-8859-1  \nen_US.UTF-8 UTF-8  \nnl_NL.UTF-8 UTF-8  \n' > "$T/locale.gen"
printf '#en_SG ISO-8859-1  \n#en_US.UTF-8 UTF-8  \n#nl_NL.UTF-8 UTF-8  \n#hrx_BR.UTF-8 UTF-8  \n' > "$T/locale.gen.pacnew"
out="$(python3 "$M" "$T/locale.gen" "$T/locale.gen.pacnew")"
grep -qx 'en_US.UTF-8 UTF-8  ' <<<"$out" || fail "en_US staat uit"
grep -qx 'nl_NL.UTF-8 UTF-8  ' <<<"$out" || fail "nl_NL staat uit"
grep -q 'hrx_BR' <<<"$out" || fail "nieuwe regel ontbreekt"
grep -q '^#en_US.UTF-8' <<<"$out" && fail "en_US staat er ook nog als commentaar"

# JSON en veel verschillen: weigeren.
printf '{\n "a": 1\n}\n' > "$T/p.json"; printf '{\n "a": 2\n}\n' > "$T/p.json.pacnew"
python3 "$M" "$T/p.json" "$T/p.json.pacnew" >/dev/null 2>&1 && fail "JSON hoort geweigerd"
printf 'a\nb\nc\nd\ne\n' > "$T/x"; printf 'v\nw\n' > "$T/x.pacnew"
python3 "$M" "$T/x" "$T/x.pacnew" >/dev/null 2>&1 && fail "vijf eigen regels hoort geweigerd"
echo "pacnew-merge: ok"
