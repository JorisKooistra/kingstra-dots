#!/usr/bin/env bash
# Overzicht van wat er op het systeem staat en wat waarschijnlijk weg kan.
# Zonder opties alleen lezen; met --review vraagt het per kandidaat of die
# weg mag (standaard nee). Pakketten die je wilt houden zet je met --keep in
# ~/.config/kingstra/package-keep.txt, dan komen ze niet meer terug.
#
# Gebruik: package_audit.sh [--summary] [--review] [--keep <pakket>...]
set -uo pipefail

KEEP_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/kingstra/package-keep.txt"
MODE="report"
UNUSED_DAYS=90
declare -a KEEP_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --summary) MODE="summary" ;;
        --review) MODE="review" ;;
        --keep)
            shift
            while [[ $# -gt 0 && "$1" != --* ]]; do
                KEEP_ARGS+=("$1")
                shift
            done
            MODE="keep"
            continue
            ;;
        -h|--help)
            sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            printf 'Onbekende optie: %s\n' "$1" >&2
            exit 2
            ;;
    esac
    shift
done

if [[ "$MODE" == "keep" ]]; then
    [[ ${#KEEP_ARGS[@]} -gt 0 ]] || { echo "Geef minstens één pakketnaam op." >&2; exit 2; }
    mkdir -p "$(dirname "$KEEP_FILE")"
    touch "$KEEP_FILE"
    for pkg in "${KEEP_ARGS[@]}"; do
        grep -qxF -- "$pkg" "$KEEP_FILE" || printf '%s\n' "$pkg" >> "$KEEP_FILE"
        echo "Bewaard: $pkg"
    done
    exit 0
fi

command -v pacman >/dev/null 2>&1 || { echo "pacman niet gevonden; dit script is voor Arch."; exit 0; }

resolve_repo() {
    local marker="${XDG_DATA_HOME:-$HOME/.local/share}/kingstra/install-complete"
    local repo="" script_path=""
    [[ -f "$marker" ]] && repo="$(sed -n 's/^Repo:[[:space:]]*//p' "$marker" | head -n 1)"
    if [[ -z "$repo" || ! -d "$repo/manifest" ]]; then
        script_path="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || true)"
        [[ -n "$script_path" ]] && repo="$(cd "$(dirname "$script_path")/../.." 2>/dev/null && pwd -P || true)"
    fi
    [[ -n "$repo" && -d "$repo/manifest/packages" ]] && printf '%s\n' "$repo"
}

# Alles wat kingstra-dots zelf installeert, ook de uitgecommentarieerde
# optionele pakketten die via een profielvlag aan kunnen staan.
manifest_packages() {
    local repo
    repo="$(resolve_repo)" || return 0
    [[ -n "$repo" ]] || return 0
    sed -nE 's/^#?[[:space:]]*(aur:)?([a-z0-9][a-z0-9@._+-]*)[[:space:]]*$/\2/p' \
        "$repo"/manifest/packages/*.txt 2>/dev/null
}

# Basis van het systeem: nooit als kandidaat tonen.
protected_packages() {
    pacman -Qgq base base-devel 2>/dev/null
    pacman -Qq 2>/dev/null | grep -E '^(base|base-devel|linux(-lts|-zen|-hardened)?(-headers)?|linux-firmware.*|.*-ucode|grub|efibootmgr|systemd-boot.*|mkinitcpio|dracut|sudo|pacman|yay|yay-bin|paru|paru-bin|networkmanager|.*-dkms|nvidia.*|mesa|vulkan-.*)$'
    [[ -f "$KEEP_FILE" ]] && grep -vE '^[[:space:]]*(#|$)' "$KEEP_FILE"
}

human_size() {
    local bytes="${1:-0}"
    awk -v b="$bytes" 'BEGIN {
        split("B KiB MiB GiB", u); i = 1
        while (b >= 1024 && i < 4) { b /= 1024; i++ }
        printf (i == 1 ? "%d %s" : "%.1f %s"), b, u[i]
    }'
}

# Naam<TAB>grootte-in-bytes<TAB>installatiedatum (epoch) voor elk pakket.
package_info() {
    LC_ALL=C pacman -Qi "$@" 2>/dev/null | awk -F' *: ' '
        /^Name/ { name = $2 }
        /^Installed Size/ {
            split($2, p, " "); n = p[1] + 0
            m = (p[2] == "KiB") ? 1024 : (p[2] == "MiB") ? 1048576 : (p[2] == "GiB") ? 1073741824 : 1
            size = int(n * m)
        }
        /^Install Date/ { date = $2 }
        /^$/ { if (name != "") print name "\t" size "\t" date; name = "" }
        END { if (name != "") print name "\t" size "\t" date }
    ' | while IFS=$'\t' read -r name size date; do
        printf '%s\t%s\t%s\n' "$name" "${size:-0}" "$(date -d "$date" +%s 2>/dev/null || echo 0)"
    done
}

# Laatste keer dat een programma van het pakket is gestart, op basis van de
# atime van de bestanden in /usr/bin (relatime werkt die dagelijks bij).
# Leeg als het pakket geen programma's heeft.
last_used() {
    local newest=0 t f
    while IFS= read -r f; do
        [[ -f "$f" ]] || continue
        t="$(stat -c %X -- "$f" 2>/dev/null || echo 0)"
        [[ "$t" -gt "$newest" ]] && newest="$t"
    done < <(pacman -Qlq "$1" 2>/dev/null | grep -E '^/usr/bin/[^/]+$')
    [[ "$newest" -gt 0 ]] && printf '%s\n' "$newest"
}

all_count="$(pacman -Qq 2>/dev/null | grep -c .)"
explicit_count="$(pacman -Qeq 2>/dev/null | grep -c .)"
foreign="$(pacman -Qmq 2>/dev/null)"
foreign_count="$(printf '%s\n' "$foreign" | grep -c .)"
git_pkgs="$(printf '%s\n' "$foreign" | grep -E -- '-(git|svn|hg|bzr|nightly)$' || true)"
orphans="$(pacman -Qdtq 2>/dev/null || true)"

# Kandidaten: zelf geïnstalleerd, niemand hangt ervan af, niet van
# kingstra-dots en niet van de basis.
known="$( { manifest_packages; protected_packages; } | sort -u)"
leaves="$(pacman -Qetq 2>/dev/null | sort -u)"
candidates="$(comm -23 <(printf '%s\n' "$leaves") <(printf '%s\n' "$known") | grep . || true)"

declare -a rows=()
if [[ -n "$candidates" ]]; then
    now="$(date +%s)"
    mapfile -t candidate_list <<< "$candidates"
    while IFS=$'\t' read -r name size installed; do
        used="$(last_used "$name")"
        if [[ -n "$used" ]]; then
            days=$(( (now - used) / 86400 ))
        else
            days=-1
        fi
        rows+=("$size"$'\t'"$name"$'\t'"$installed"$'\t'"$days")
    done < <(package_info "${candidate_list[@]}")
fi

unused_count=0
for row in "${rows[@]}"; do
    IFS=$'\t' read -r _ _ _ days <<< "$row"
    [[ "$days" -ge "$UNUSED_DAYS" ]] && unused_count=$((unused_count + 1))
done

if [[ "$MODE" == "summary" ]]; then
    printf '%s pakketten, waarvan %s zelf gekozen en %s uit AUR.\n' "$all_count" "$explicit_count" "$foreign_count"
    printf '%s kandidaten om op te ruimen, %s daarvan %s+ dagen niet gestart.\n' "${#rows[@]}" "$unused_count" "$UNUSED_DAYS"
    [[ -n "$orphans" ]] && printf '%s verweesde pakketten.\n' "$(printf '%s\n' "$orphans" | grep -c .)"
    exit 0
fi

echo "=============================================="
echo " Kingstra pakketoverzicht"
echo "=============================================="
printf 'Geïnstalleerd:  %s pakketten\n' "$all_count"
printf 'Zelf gekozen:   %s (de rest zijn afhankelijkheden)\n' "$explicit_count"
printf 'Uit AUR:        %s\n' "$foreign_count"
if command -v flatpak >/dev/null 2>&1; then
    printf 'Flatpak:        %s apps, %s runtimes\n' \
        "$(flatpak list --app --columns=application 2>/dev/null | grep -c .)" \
        "$(flatpak list --runtime --columns=application 2>/dev/null | grep -c .)"
fi

if [[ -n "$git_pkgs" ]]; then
    echo
    echo "AUR-ontwikkelversies (bouwen bij elke commit opnieuw, zoek een -bin of"
    echo "repo-versie als je ze niet bewust volgt):"
    printf '%s\n' "$git_pkgs" | sed 's/^/  /'
fi

if [[ -n "$orphans" ]]; then
    echo
    echo "Verweesde pakketten (niemand gebruikt ze nog; de updater ruimt ze op bij 'j'):"
    printf '%s\n' "$orphans" | sed 's/^/  /'
fi

echo
if [[ ${#rows[@]} -eq 0 ]]; then
    echo "Geen kandidaten: alles wat je zelf installeerde hoort bij kingstra-dots of de basis."
    exit 0
fi

echo "Kandidaten om op te ruimen (zelf geïnstalleerd, niet van kingstra-dots,"
echo "niets hangt ervan af). Grootste eerst:"
printf '  %-34s %10s  %-11s  %s\n' "Pakket" "Grootte" "Sinds" "Laatst gestart"
mapfile -t rows < <(printf '%s\n' "${rows[@]}" | sort -t$'\t' -k1,1nr)
for row in "${rows[@]}"; do
    IFS=$'\t' read -r size name installed days <<< "$row"
    if [[ "$days" -lt 0 ]]; then
        used="geen programma"
    elif [[ "$days" -eq 0 ]]; then
        used="vandaag"
    else
        used="$days dagen geleden"
    fi
    [[ "$days" -ge "$UNUSED_DAYS" ]] && used="$used  ← ongebruikt"
    printf '  %-34s %10s  %-11s  %s\n' "$name" "$(human_size "$size")" \
        "$(date -d "@$installed" +%Y-%m-%d 2>/dev/null || echo '?')" "$used"
done

echo
echo "Houden: $0 --keep <pakket>   ·   Opruimen per pakket: $0 --review"

[[ "$MODE" == "review" ]] || exit 0

echo
echo "Per pakket: j = verwijderen (met afhankelijkheden die dan overblijven),"
echo "h = houden en niet meer vragen, Enter = overslaan."
declare -a remove=()
for row in "${rows[@]}"; do
    IFS=$'\t' read -r _ name _ _ <<< "$row"
    reply=""
    read -r -p "  $name? [j/h/N] " reply || break
    case "$reply" in
        [jJyY]*) remove+=("$name") ;;
        [hH]*) "$0" --keep "$name" >/dev/null && echo "    bewaard" ;;
    esac
done

if [[ ${#remove[@]} -eq 0 ]]; then
    echo "Niets verwijderd."
    exit 0
fi
echo
echo "Wordt verwijderd: ${remove[*]}"
sudo pacman -Rns -- "${remove[@]}"
