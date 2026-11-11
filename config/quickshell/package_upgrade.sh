#!/usr/bin/env bash
# Kingstra Update Runner: Arch-nieuws, Arch/AUR, Flatpak en dotfiles in één run.
# In een terminal toont het per stap een korte samenvatting en een
# voortgangsbalk; de volledige uitvoer van yay/flatpak gaat naar het log.
#
# Gebruik: kingstra update [alles|dotfiles|--check] [--interactief]
#   zonder keuze   in een terminal eerst een keuzemenu
#   alles          systeem (pacman), AUR, Flatpak en dotfiles  (--alles)
#   dotfiles       alleen de dotfiles + installer, geen pakketupdates  (--dotfiles)
#   --check        proefdraai: wat de update zou tegenhouden  (--proef)
#   --interactief  yay en flatpak met hun eigen uitvoer en vragen
set -uo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell"
COUNT_SCRIPT="${HOME}/.config/quickshell/package_updates.sh"
AUDIT_SCRIPT="${HOME}/.config/quickshell/package_audit.sh"
SELF_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
SHARED_SCRIPTS="$(cd "$SELF_DIR/../shared/scripts" 2>/dev/null && pwd -P || true)"
# Eerst de geïnstalleerde versie, anders die uit de repo: bij de eerste
# update na een nieuwe release staat ~/.local/bin nog niet klaar.
find_tool() {
    local name="$1"
    if [[ -x "$HOME/.local/bin/$name" ]]; then
        printf '%s' "$HOME/.local/bin/$name"
    elif [[ -n "$SHARED_SCRIPTS" && -f "$SHARED_SCRIPTS/$name" ]]; then
        printf '%s' "$SHARED_SCRIPTS/$name"
    fi
}
SNAPSHOT_CMD="${KINGSTRA_SNAPSHOT_CMD:-$(find_tool kingstra-snapshot)}"
HEALTH_CMD="$(find_tool kingstra-health)"
ROLLBACK_CMD="$(find_tool kingstra-rollback)"
MERGE_CMD="$(find_tool kingstra-pacnew-merge)"
AUR_CACHE_CMD="$(find_tool kingstra-aur-cache)"
PACMAN_LOG="${KINGSTRA_PACMAN_LOG:-/var/log/pacman.log}"
RESULT_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/kingstra/update-result.json"
HOLD_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/kingstra/update-hold"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/kingstra/updates"
LAST_RUN_FILE="$STATE_DIR/last-run"
# Bij welke stap de lopende update is; blijft staan als hij afbreekt.
PROGRESS_FILE="$STATE_DIR/in-progress"
NEWS_URL="https://archlinux.org/feeds/news/"
LOG_KEEP=10
overall_exit=0
DOTFILES_REPO=""
LOG_FILE=""

# Pakketten die bij een update het vermelden waard zijn.
NOTABLE_RE='^(linux(-lts|-zen|-hardened)?|linux-firmware|nvidia[^ ]*|mesa|vulkan-[^ ]+|systemd|glibc|hyprland|hyprlock|hypridle|quickshell[^ ]*|pipewire|wireplumber|sddm|networkmanager|bluez|grub|mkinitcpio) '
INLINE_MAX=6

ORIG_ARGS=("$@")
SELF="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")"

INTERACTIVE=false
# --check / --proef: alles nalopen wat de update kan laten mislukken, zonder
# iets te installeren of de dotfiles te veranderen.
CHECK=false
# alles | dotfiles; leeg = in een terminal vragen, anders alles.
MODE=""
for arg in "$@"; do
    case "$arg" in
        --interactief|--interactive) INTERACTIVE=true ;;
        --check|--proef|check|proef) CHECK=true ;;
        --dotfiles|--alleen-dotfiles|dotfiles) MODE="dotfiles" ;;
        --alles|--systeem|--all|alles|systeem) MODE="alles" ;;
        -h|--help|help)
            sed -n '6,11p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0 ;;
    esac
done
$INTERACTIVE && [[ -z "$MODE" ]] && MODE="alles"

# ---------------------------------------------------------------------------
# Weergave
# ---------------------------------------------------------------------------
UI=false
[[ -t 0 && -t 1 && "${TERM:-}" != "dumb" ]] && UI=true

STEPS_TOTAL=10
STEP_NUM=0
STEP_TITLE=""
SUMMARY=()
LIVE_SHOWN=false
SPIN_IDX=0

C_RESET="" C_BOLD="" C_DIM="" C_GREEN="" C_YELLOW="" C_RED="" C_CYAN=""
G_OK="OK" G_WARN="!" G_FAIL="X" G_DOT="-" G_ASK="?" BAR_FULL="#" BAR_EMPTY="-"
SPIN=('-' '\' '|' '/')
if $UI; then
    C_RESET=$'\033[0m' C_BOLD=$'\033[1m' C_DIM=$'\033[2m'
    C_GREEN=$'\033[32m' C_YELLOW=$'\033[33m' C_RED=$'\033[31m' C_CYAN=$'\033[36m'
    if [[ "$(locale charmap 2>/dev/null)" == "UTF-8" || "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" =~ [Uu][Tt][Ff]-?8 ]]; then
        G_OK="✓" G_WARN="!" G_FAIL="✗" G_DOT="·" G_ASK="?" BAR_FULL="█" BAR_EMPTY="░"
        SPIN=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    fi
fi

bar() {
    local total="$1" current="$2" width="${3:-24}" filled=0 i out=""
    (( total > 0 )) && filled=$((current * width / total))
    (( filled > width )) && filled=$width
    for (( i = 0; i < width; i++ )); do
        if (( i < filled )); then out+="$BAR_FULL"; else out+="$BAR_EMPTY"; fi
    done
    printf '%s' "$out"
}

term_cols() {
    local cols
    cols="$(tput cols 2>/dev/null || true)"
    [[ "$cols" =~ ^[0-9]+$ ]] || cols="${COLUMNS:-80}"
    [[ "$cols" =~ ^[0-9]+$ ]] || cols=80
    printf '%s' "$cols"
}

# m:ss sinds $1 (epoch-seconden).
elapsed_since() {
    local s=$(( $(date +%s) - $1 ))
    (( s < 0 )) && s=0
    printf '%d:%02d' $((s / 60)) $((s % 60))
}

# Eén regel die steeds overschreven wordt: spinner, tijd sinds het begin van
# deze deelstap (LIVE_T0), optionele balk, tekst. De lopende tijd laat zien
# dat er nog iets gebeurt, ook als een stap minuten stil is.
LIVE_T0=""
live() {
    $UI || return 0
    local msg="$1" done="${2:-}" total="${3:-}" prefix plain max clock=""
    local spin="${SPIN[SPIN_IDX % ${#SPIN[@]}]}"
    SPIN_IDX=$((SPIN_IDX + 1))
    [[ -n "$LIVE_T0" ]] && clock="$(elapsed_since "$LIVE_T0") "
    if [[ -n "$total" && "$total" -gt 0 ]]; then
        plain="    $spin $clock$(bar "$total" "$done" 20) $done/$total  "
        prefix="    ${C_CYAN}${spin}${C_RESET} ${C_DIM}${clock}${C_RESET}${C_GREEN}$(bar "$total" "$done" 20)${C_RESET} ${C_BOLD}${done}/${total}${C_RESET}  "
    else
        plain="    $spin $clock"
        prefix="    ${C_CYAN}${spin}${C_RESET} ${C_DIM}${clock}${C_RESET}"
    fi
    max=$(( $(term_cols) - ${#plain} - 1 ))
    (( max < 10 )) && max=10
    (( ${#msg} > max )) && msg="${msg:0:$((max - 1))}…"
    printf '\033[?25l\r\033[K%s%s%s%s' "$prefix" "$C_DIM" "$msg" "$C_RESET"
    LIVE_SHOWN=true
}

live_clear() {
    $UI || return 0
    if $LIVE_SHOWN; then
        printf '\r\033[K'
        LIVE_SHOWN=false
    fi
    printf '\033[?25h'
}
trap 'live_clear' EXIT

to_log() {
    [[ -n "$LOG_FILE" ]] && printf '%s\n' "$@" >> "$LOG_FILE"
    return 0
}

section() {
    STEP_NUM=$((STEP_NUM + 1))
    STEP_TITLE="$1"
    to_log "" "== $1 =="
    if ! $CHECK && [[ "$1" != "Klaar" ]]; then
        mkdir -p "$STATE_DIR" 2>/dev/null
        printf '%s\t%s\t%s\n' "$(date +%s)" "$1" "${LOG_FILE:-}" > "$PROGRESS_FILE" 2>/dev/null || true
    fi
    if $UI; then
        live_clear
        # Venstertitel: ook als het venster klein of op de achtergrond staat
        # zie je in welke stap de update zit.
        printf '\033]2;Kingstra update %d/%d · %s\007' "$STEP_NUM" "$STEPS_TOTAL" "$1"
        printf '\n  %s%s%s %s%d/%d%s  %s%s%s\n' \
            "$C_GREEN" "$(bar "$STEPS_TOTAL" "$((STEP_NUM - 1))" 14)" "$C_RESET" \
            "$C_DIM" "$STEP_NUM" "$STEPS_TOTAL" "$C_RESET" "$C_BOLD" "$1" "$C_RESET"
        return 0
    fi
    printf '\n%s\n' "──────────────────────────────────────────────"
    printf '%s\n' "$1"
    printf '%s\n\n' "──────────────────────────────────────────────"
}

# Het resultaat van een stap; komt ook terug in de eindsamenvatting.
result() {
    local kind="$1" msg="$2" glyph color
    case "$kind" in
        ok) glyph="$G_OK"; color="$C_GREEN" ;;
        warn) glyph="$G_WARN"; color="$C_YELLOW" ;;
        *) glyph="$G_FAIL"; color="$C_RED" ;;
    esac
    SUMMARY+=("$kind|$STEP_TITLE|$msg")
    to_log "[$kind] $msg"
    if $UI; then
        live_clear
        printf '    %s%s%s %s\n' "$color" "$glyph" "$C_RESET" "$msg"
    else
        printf '%s\n' "$msg"
    fi
}

log() {
    if $UI; then
        live_clear
        printf '    %s\n' "$*"
    else
        printf '%s\n' "$*"
    fi
    to_log "$*"
}

log_block() {
    local text="$1"
    [[ -n "$text" ]] || return 0
    if $UI; then
        live_clear
        printf '%s\n' "$text" | sed 's/^/    /'
    else
        printf '%s\n' "$text"
    fi
    to_log "$text"
}

# Toont hoogstens INLINE_MAX namen op één regel; de rest staat in het log.
inline_names() {
    local -a names=()
    mapfile -t names < <(printf '%s\n' "$1" | awk 'NF { print $1 }')
    local n=${#names[@]} shown="${names[*]:0:$INLINE_MAX}"
    shown="${shown// /, }"
    (( n > INLINE_MAX )) && shown+=" en nog $((n - INLINE_MAX))"
    printf '%s' "$shown"
}

count_lines() {
    [[ -n "$1" ]] || { printf '0'; return; }
    printf '%s\n' "$1" | grep -c .
}

# Het log bevat de samenvatting van elke run plus de volledige uitvoer van
# de stappen die stil (met voortgangsbalk) draaien.
init_log() {
    mkdir -p "$STATE_DIR" 2>/dev/null || return 0
    # Na het opnieuw starten met de nieuwe updater: hetzelfde log aanvullen.
    if [[ -n "${KINGSTRA_UPDATE_LOG:-}" && -w "$KINGSTRA_UPDATE_LOG" ]]; then
        LOG_FILE="$KINGSTRA_UPDATE_LOG"
        return 0
    fi
    LOG_FILE="$STATE_DIR/update-$(date +%Y%m%d-%H%M%S).log"
    : > "$LOG_FILE" 2>/dev/null || LOG_FILE=""

    local old
    while IFS= read -r old; do
        rm -f -- "$old"
    done < <(find "$STATE_DIR" -maxdepth 1 -name 'update-*.log' -printf '%T@ %p\n' 2>/dev/null \
        | sort -rn | tail -n +$((LOG_KEEP + 1)) | cut -d' ' -f2-)
}

# Wat pacman/yay op dit moment doet, in gewone woorden. pacman nummert elke
# fase opnieuw ("( 3/87) ..."), dus zonder de kop ervoor (":: Retrieving
# packages", ":: Processing package changes", ":: Running post-transaction
# hooks") lijkt de balk steeds opnieuw te beginnen. Zet PROG_LABEL, PROG_DONE,
# PROG_TOTAL en PROG_KERNEL (true zodra de kernel-/initramfs-stap bezig is).
PROG_LABEL="" PROG_DONE="" PROG_TOTAL="" PROG_KERNEL=false PROG_EXPECT=""
describe_output() {
    local file="$1" fallback="$2" tail header="" last="" counter="" what="" made=0
    PROG_LABEL="" PROG_DONE="" PROG_TOTAL=""
    tail="$(tail -n 300 "$file" 2>/dev/null | tr '\r' '\n' | sed 's/\x1b\[[0-9;?]*[A-Za-z]//g' | awk 'NF')"
    last="$(printf '%s\n' "$tail" | tail -n 1)"
    header="$(printf '%s\n' "$tail" | grep -E '^(:: |==> Making package:)' | tail -n 1 || true)"
    counter="$(printf '%s\n' "$tail" | grep -E '^\( *[0-9]+/[0-9]+\) ' | tail -n 1 || true)"
    if [[ "$counter" =~ ^\(\ *([0-9]+)/([0-9]+)\)\ +(.*)$ ]]; then
        PROG_DONE="${BASH_REMATCH[1]}" PROG_TOTAL="${BASH_REMATCH[2]}" what="${BASH_REMATCH[3]}"
    fi

    # Kernel: tussen "Removing linux initcpios" en het nieuwe opstartbestand
    # staat er geen werkende kernel op /boot. Daar ging het op 10-11 mis.
    # PROG_KERNEL blijft staan (voor de waarschuwing); het label alleen zolang
    # de kernel-hook zelf bezig is.
    local kernel_re='initcpios|Building image from preset|Running build hook|Image generation|initcpio image|kernel-install|UKI'
    if printf '%s\n' "$tail" | grep -qE 'initcpios|Building image from preset|kernel-install'; then
        PROG_KERNEL=true
    fi
    if printf '%s\n' "$what" | grep -qE "$kernel_re" \
        || { [[ ! "$last" =~ ^\(\ *[0-9]+/[0-9]+\) ]] && printf '%s\n' "$last" | grep -qE "$kernel_re"; }; then
        local sub=""
        if [[ "$last" =~ preset:\ .*/([^/]+)\.preset:\ \'([^\']+)\' ]]; then
            sub="${BASH_REMATCH[1]} (${BASH_REMATCH[2]})"
        elif [[ "$last" =~ build\ hook:\ \[([^]]+)\] ]]; then
            sub="hook ${BASH_REMATCH[1]}"
        elif [[ "$last" =~ (Image generation successful|Creating .* initcpio image) ]]; then
            sub="${BASH_REMATCH[1]}"
        fi
        if [[ "$what" == Removing* ]]; then
            PROG_LABEL="Kernel: oude opstartbestanden weghalen"
        else
            PROG_LABEL="Kernel: nieuwe opstartbestanden bouwen${sub:+ · $sub}"
        fi
        PROG_DONE="" PROG_TOTAL=""
        return 0
    fi

    case "$header" in
        *"Synchronizing package databases"*|*"Synchronising package databases"*)
            PROG_LABEL="Pakketlijsten ophalen" ;;
        *"Starting full system upgrade"*|*"Searching databases for updates"*|*"Searching AUR for updates"*)
            PROG_LABEL="Updates op een rij zetten" ;;
        *"Retrieving packages"*)
            PROG_LABEL="Downloaden" ;;
        *"Running pre-transaction hooks"*)
            PROG_LABEL="Voorbereiden" ;;
        *"Processing package changes"*)
            PROG_LABEL="Installeren" ;;
        *"Running post-transaction hooks"*)
            PROG_LABEL="Afronden" ;;
        *"Making package:"*)
            what="${header#*Making package: }"
            PROG_LABEL="AUR bouwen: ${what%% *}" what="" ;;
    esac
    # Zonder terminal nummert pacman de controles en het installeren niet
    # ("checking keyring...", "upgrading foo..."); dan de laatste regel lezen
    # en zelf tellen tegen het aantal klaarstaande updates.
    if [[ -z "$what" && "$last" =~ ^(checking|loading|upgrading|installing|reinstalling|downgrading|removing)\ (.*)$ ]]; then
        what="$last"
        what="${what%...}"
        if [[ "$what" =~ ^(upgrading|installing|reinstalling|downgrading)\  ]]; then
            local n
            n="$(sed -n '/^:: Processing package changes/,$p' "$file" 2>/dev/null \
                | grep -cE '^(upgrading|installing|reinstalling|downgrading) ' || true)"
            local expect="${PROG_EXPECT:-$REPO_COUNT}"
            if (( expect > 0 && n > 0 )); then
                PROG_DONE="$n" PROG_TOTAL="$expect"
                (( PROG_DONE > PROG_TOTAL )) && PROG_TOTAL="$PROG_DONE"
            fi
        fi
    fi
    case "$what" in
        "checking keyring"*) PROG_LABEL="Sleutels controleren" what="" ;;
        "checking keys in keyring"*) PROG_LABEL="Sleutels controleren" what="" ;;
        "checking package integrity"*) PROG_LABEL="Pakketten controleren" what="" ;;
        "loading package files"*) PROG_LABEL="Pakketten laden" what="" ;;
        "checking for file conflicts"*) PROG_LABEL="Bestandsconflicten zoeken" what="" ;;
        "checking available disk space"*) PROG_LABEL="Schijfruimte controleren" what="" ;;
        upgrading\ *|installing\ *|reinstalling\ *|downgrading\ *)
            PROG_LABEL="Installeren" what="${what#* }" ;;
        removing\ *)
            PROG_LABEL="Verwijderen" what="${what#* }" ;;
    esac
    # AUR: geen teller van pacman tijdens het bouwen; tel de pakketten zelf.
    if [[ "$PROG_LABEL" == "AUR bouwen:"* ]]; then
        made="$(grep -c 'Making package:' "$file" 2>/dev/null || true)"
        if (( AUR_COUNT > 0 && made > 0 )); then
            PROG_DONE="$made" PROG_TOTAL="$AUR_COUNT"
            (( PROG_DONE > PROG_TOTAL )) && PROG_TOTAL="$PROG_DONE"
        fi
        what="$(sed -E 's/^ *(->|==>) *//' <<< "$last")"
    fi
    if [[ -z "$PROG_LABEL" ]]; then
        PROG_LABEL="$fallback"
        what="${what:-$last}"
    fi
    [[ -n "$what" ]] && PROG_LABEL+=": $what"
    return 0
}

# Draait een commando stil: uitvoer naar het log, in de terminal een
# voortgangsregel met de lopende tijd, wat er nu gebeurt en (als pacman telt)
# een balk. Zodra de kernel-stap begint verschijnt één vaste waarschuwing.
QUIET_DETACHED=false
run_quiet() {
    local label="$1"
    shift
    local tmp rc=0 kernel_noted=false
    QUIET_TAIL=""
    PROG_KERNEL=false
    tmp="$(mktemp)"
    to_log "\$ $*"
    LIVE_T0="$(date +%s)"
    "$@" </dev/null >"$tmp" 2>&1 &
    local pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        describe_output "$tmp" "$label"
        if $PROG_KERNEL && ! $kernel_noted; then
            kernel_noted=true
            # Bewust geen result: het is een melding, geen probleem voor de samenvatting.
            if $QUIET_DETACHED; then
                log "${C_YELLOW}${G_WARN}${C_RESET} ${C_BOLD}Kernel-stap begonnen${C_RESET} (1 tot 3 minuten). Zet de pc niet uit; dit venster sluiten mag, pacman loopt als dienst door."
            else
                log "${C_YELLOW}${G_WARN}${C_RESET} ${C_BOLD}Kernel-stap begonnen${C_RESET} (1 tot 3 minuten). Zet de pc niet uit en sluit dit venster niet."
            fi
        fi
        live "$PROG_LABEL" "$PROG_DONE" "$PROG_TOTAL"
        sleep 0.2
    done
    wait "$pid" || rc=$?
    [[ -n "$LOG_FILE" ]] && cat "$tmp" >> "$LOG_FILE"
    QUIET_TAIL="$(tr '\r' '\n' < "$tmp" | sed 's/\x1b\[[0-9;]*[A-Za-z]//g' | awk 'NF' | tail -n 8)"
    live_clear
    if $UI; then
        printf '    %s%s klaar in %s%s\n' "$C_DIM" "$label" "$(elapsed_since "$LIVE_T0")" "$C_RESET"
    fi
    to_log "($label: $(elapsed_since "$LIVE_T0"), code $rc)"
    LIVE_T0=""
    if (( rc != 0 )); then
        printf '    %sLaatste uitvoer:%s\n' "$C_DIM" "$C_RESET"
        tr '\r' '\n' < "$tmp" | awk 'NF' | tail -n 8 | sed 's/^/      /'
    fi
    rm -f "$tmp"
    return "$rc"
}

# Ja/nee-vragen. Zonder terminal (of bij EOF) geldt het standaardantwoord,
# zodat het script nooit blijft hangen en niets ongevraagd verwijdert.
ask_no() {
    local reply=""
    live_clear
    if $UI; then
        read -r -p "    ${C_CYAN}${G_ASK}${C_RESET} $1 ${C_DIM}[j/N]${C_RESET} " reply || return 1
    else
        read -r -p "$1 [j/N] " reply || return 1
    fi
    [[ "$reply" =~ ^[jJyY] ]]
}

ask_yes() {
    local reply=""
    live_clear
    if $UI; then
        read -r -p "    ${C_CYAN}${G_ASK}${C_RESET} $1 ${C_DIM}[J/n]${C_RESET} " reply || return 0
    else
        read -r -p "$1 [J/n] " reply || return 0
    fi
    [[ ! "$reply" =~ ^[nN] ]]
}

QUIET_TAIL=""
DOTFILES_SKIP=""
REPO_LIST=""
REPO_COUNT=0
AUR_COUNT=0
AUR_LIST=""
FLATPAK_COUNT=0

# Korte samenvatting per bron; de volledige lijsten gaan naar het log.
preview_updates() {
    local repo_list="" aur_list="" flatpak_list="" helper="" notable=""

    live "Updates zoeken"
    if command -v checkupdates >/dev/null 2>&1; then
        repo_list="$(timeout 90 checkupdates 2>/dev/null || true)"
    fi
    if command -v yay >/dev/null 2>&1; then
        helper="yay"
    elif command -v paru >/dev/null 2>&1; then
        helper="paru"
    fi
    if [[ -n "$helper" ]]; then
        live "AUR-updates zoeken"
        aur_list="$(timeout 90 "$helper" -Qua 2>/dev/null || true)"
        drop_stale_git "$aur_list"
        aur_list="$AUR_KEPT"
    fi
    if command -v flatpak >/dev/null 2>&1; then
        live "Flatpak-updates zoeken"
        flatpak_list="$(timeout 90 flatpak remote-ls --updates --columns=application,version 2>/dev/null || true)"
    fi
    live_clear

    REPO_LIST="$repo_list"
    REPO_COUNT="$(count_lines "$repo_list")"
    AUR_COUNT="$(count_lines "$aur_list")"
    AUR_LIST="$aur_list"
    FLATPAK_COUNT="$(count_lines "$flatpak_list")"

    if [[ -z "$repo_list$aur_list$flatpak_list" ]]; then
        log "Geen pakket- of Flatpak-updates gevonden (of de check kon niet draaien)."
        return 0
    fi

    to_log "-- Arch ($REPO_COUNT) --" "$repo_list" "-- AUR ($AUR_COUNT) --" "$aur_list" \
        "-- Flatpak ($FLATPAK_COUNT) --" "$flatpak_list"

    log "${C_BOLD}Arch $REPO_COUNT${C_RESET} $G_DOT ${C_BOLD}AUR $AUR_COUNT${C_RESET} $G_DOT ${C_BOLD}Flatpak $FLATPAK_COUNT${C_RESET}"
    notable="$(printf '%s\n' "$repo_list" | grep -E "$NOTABLE_RE" | awk '{ printf "%s%s %s", (NR > 1 ? ", " : ""), $1, $NF }')"
    [[ -n "$notable" ]] && log "Belangrijk: $notable"
    [[ -n "$aur_list" ]] && log "AUR: $(inline_names "$aur_list")"
    [[ -n "$flatpak_list" ]] && log "Flatpak: $(inline_names "$flatpak_list")"
    [[ -n "$LOG_FILE" ]] && log "${C_DIM}Volledige lijst in het log.${C_RESET}"
    if printf '%s\n' "$repo_list" | grep -qE '^linux(-lts|-zen|-hardened)? '; then
        result warn "Er zit een kernel-update bij; na afloop is een herstart nodig."
    fi
}

# Toont Arch-nieuws sinds de vorige run (eerste keer: de drie nieuwste).
# Nieuws vraagt soms handwerk vóór een update, dus bij nieuwe berichten wacht
# het script op een bevestiging.
check_arch_news() {
    local feed="" last_run=0 shown=0 title="" pub="" ts=0 latest=""

    command -v curl >/dev/null 2>&1 || {
        log "curl ontbreekt; Arch-nieuws overgeslagen."
        return 0
    }
    feed="$(curl -fsSL --max-time 8 "$NEWS_URL" 2>/dev/null || true)"
    if [[ -z "$feed" ]]; then
        log "Arch-nieuws kon niet worden opgehaald; overgeslagen."
        return 0
    fi

    [[ -f "$LAST_RUN_FILE" ]] && read -r last_run < "$LAST_RUN_FILE"
    [[ "$last_run" =~ ^[0-9]+$ ]] || last_run=0

    while IFS=$'\t' read -r title pub; do
        [[ -n "$title" ]] || continue
        [[ -n "$latest" ]] || latest="$(date -d "$pub" +%Y-%m-%d 2>/dev/null || echo '?')  $title"
        ts="$(date -d "$pub" +%s 2>/dev/null || echo 0)"
        if [[ "$last_run" -eq 0 && "$shown" -ge 3 ]] || [[ "$last_run" -gt 0 && "$ts" -le "$last_run" ]]; then
            break
        fi
        log "  $(date -d "$pub" +%Y-%m-%d 2>/dev/null || echo '?')  $title"
        shown=$((shown + 1))
    done < <(printf '%s' "$feed" | tr -d '\n' | sed 's/<item>/\n/g' | tail -n +2 \
        | sed -nE 's|.*<title>([^<]*)</title>.*<pubDate>([^<]*)</pubDate>.*|\1\t\2|p' \
        | sed 's/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g; s/&quot;/"/g; s/&#39;/'"'"'/g')

    if [[ "$shown" -eq 0 ]]; then
        log "Geen nieuw Arch-nieuws sinds de vorige update."
        [[ -n "$latest" ]] && log "Laatste bericht: $latest"
        return 0
    fi
    log "Lees ze op https://archlinux.org/news/ als er handwerk bij staat."
    $CHECK && return 0
    if ! ask_yes "Doorgaan met updaten?"; then
        log "Update op verzoek gestopt na het nieuws."
        return 1
    fi
}

# .pacnew en .pacsave: per bestand het verschil tonen en samen beslissen.
# Zonder terminal alleen melden, zoals voorheen.
report_pacnew() {
    local files="" f base reply n=0 kept=0 took=0 later=0 stamp merged="" choices
    command -v pacman >/dev/null 2>&1 || return 0
    files="$(find /etc -xdev \( -name '*.pacnew' -o -name '*.pacsave' \) 2>/dev/null | sort)"
    if [[ -z "$files" ]]; then
        result ok "Geen .pacnew- of .pacsave-bestanden in /etc."
        return 0
    fi
    to_log "$files"
    n="$(count_lines "$files")"
    if ! $UI || ! ask_yes "$n configbestand(en) hebben een nieuwe versie. Nu samen nalopen?"; then
        result warn "$n configbestand(en) wachten nog: $(inline_names "$files") (later: kingstra update)"
        return 0
    fi
    stamp="$(date +%Y%m%d)"
    while IFS= read -r f; do
        [[ -n "$f" ]] || continue
        if [[ "$f" == *.pacsave ]]; then
            log "${C_BOLD}$f${C_RESET} ${C_DIM}(oude instellingen van een verwijderd of vervangen pakket)${C_RESET}"
            if ask_no "Weggooien?"; then
                sudo rm -f -- "$f" && took=$((took + 1))
            else
                later=$((later + 1))
            fi
            continue
        fi
        base="${f%.pacnew}"
        log "${C_BOLD}$base${C_RESET}"
        if [[ "$base" == /etc/pacman.d/mirrorlist ]] && systemctl is-enabled --quiet reflector.timer 2>/dev/null; then
            log "${C_DIM}reflector houdt deze lijst zelf bij; de nieuwe versie is niet nodig.${C_RESET}"
            sudo rm -f -- "$f" && kept=$((kept + 1))
            continue
        fi
        sudo diff -u --label "nu" --label "nieuw" "$base" "$f" 2>/dev/null \
            | tail -n +3 | head -n 30 | sed 's/^/      /'
        # Samenvoegen: nieuwe versie plus wat jij zelf aanzette of toevoegde.
        rm -f -- "$merged"
        merged=""
        choices="[n]ieuwe overnemen, [e]igen houden, [l]ater ${C_DIM}[l]${C_RESET}"
        if [[ -n "$MERGE_CMD" ]]; then
            merged="$(mktemp)"
            # shellcheck disable=SC2024  # tijdelijk bestand is van de gebruiker
            if sudo python3 "$MERGE_CMD" "$base" "$f" > "$merged" 2>/dev/null \
                && ! sudo cmp -s "$merged" "$f" && ! sudo cmp -s "$merged" "$base"; then
                log "${C_DIM}Samengevoegd: de nieuwe versie, met jouw eigen regels erin:${C_RESET}"
                sudo diff -u --label "nu" --label "samengevoegd" "$base" "$merged" 2>/dev/null \
                    | tail -n +3 | head -n 20 | sed 's/^/      /'
                choices="[s]amenvoegen (aanbevolen), [n]ieuwe overnemen, [e]igen houden, [l]ater ${C_DIM}[s]${C_RESET}"
            else
                rm -f -- "$merged"
                merged=""
            fi
        fi
        live_clear
        read -r -p "    ${C_CYAN}${G_ASK}${C_RESET} $choices " reply || reply="l"
        [[ -z "$reply" && -n "$merged" ]] && reply="s"
        case "$reply" in
            s|S)
                if [[ -z "$merged" ]]; then
                    later=$((later + 1))
                    continue
                fi
                sudo cp -a -- "$base" "$base.kingstra-$stamp" 2>/dev/null
                # tee houdt eigenaar en rechten van het bestaande bestand.
                if sudo tee "$base" < "$merged" >/dev/null && sudo rm -f -- "$f"; then
                    took=$((took + 1))
                    to_log "samengevoegd: $f (oude versie: $base.kingstra-$stamp)"
                fi ;;
            n|N)
                sudo cp -a -- "$base" "$base.kingstra-$stamp" 2>/dev/null
                if sudo mv -f -- "$f" "$base"; then
                    took=$((took + 1))
                    to_log "overgenomen: $f (oude versie: $base.kingstra-$stamp)"
                fi ;;
            e|E)
                sudo rm -f -- "$f" && kept=$((kept + 1)) && to_log "eigen gehouden: $base" ;;
            *) later=$((later + 1)) ;;
        esac
    done <<< "$files"
    [[ -n "$merged" ]] && rm -f -- "$merged"
    if (( later > 0 )); then
        result warn "Configbestanden: $took nieuw, $kept eigen gehouden, $later voor later."
    else
        result ok "Configbestanden: $took nieuw, $kept eigen gehouden."
    fi
}

# Wat pacman echt deed sinds $1 (lokale tijd, YYYY-mm-ddTHH:MM:SS), uit
# pacman.log. Schrijft de transactie weg, zodat `kingstra rollback --system`
# haar kan terugdraaien.
TX_UPGRADED=0
TX_INSTALLED=0
TX_FILE=""
record_transaction() {
    local since="$1" lines=""
    [[ -r "$PACMAN_LOG" ]] || return 1
    lines="$(awk -v since="$since" '
        /^\[[0-9]{4}-[0-9]{2}-[0-9]{2}T[^]]*\] \[ALPM\] (upgraded|installed|downgraded|removed) / {
            ts = substr($1, 2, 19)
            if (ts < since) next
            action = $3; name = $4
            ver = $0; sub(/^[^(]*\(/, "", ver); sub(/\)$/, "", ver)
            old = ""; new = ver
            if (index(ver, " -> ") > 0) { split(ver, v, " -> "); old = v[1]; new = v[2] }
            if (action == "removed") { old = ver; new = "" }
            printf "%s\t%s\t%s\t%s\n", action, name, old, new
        }' "$PACMAN_LOG" 2>/dev/null)"
    TX_UPGRADED="$(printf '%s\n' "$lines" | grep -c '^upgraded' || true)"
    TX_INSTALLED="$(printf '%s\n' "$lines" | grep -c '^installed' || true)"
    [[ -n "$lines" ]] || return 0
    mkdir -p "$STATE_DIR/transacties" 2>/dev/null || return 0
    TX_FILE="$STATE_DIR/transacties/$(date +%Y%m%d-%H%M%S).tsv"
    printf '%s\n' "$lines" > "$TX_FILE"
    # Alleen de laatste 20 transacties bewaren.
    find "$STATE_DIR/transacties" -name '*.tsv' -printf '%T@ %p\n' 2>/dev/null | sort -rn \
        | tail -n +21 | cut -d' ' -f2- | xargs -r rm -f --
    to_log "Transactie: $TX_FILE ($TX_UPGRADED bijgewerkt, $TX_INSTALLED nieuw)"
}

# Controleert of de update echt gelukt is. yay kan met code 0 eindigen terwijl
# pacman niets installeerde (2 november: "bijgewerkt", maar 88 updates open);
# dan zeggen we dat eerlijk, met de laatste regels van yay erbij.
verify_arch() {
    local since="$1" rc="$2" remaining="" n_left=0
    record_transaction "$since" || true
    if command -v checkupdates >/dev/null 2>&1; then
        live "Controleren of alles erop staat"
        remaining="$(timeout 90 checkupdates 2>/dev/null || true)"
        live_clear
    fi
    n_left="$(count_lines "$remaining")"
    to_log "-- Nog open na de update ($n_left) --" "$remaining"

    if (( rc == 0 && REPO_COUNT > 0 && TX_UPGRADED + TX_INSTALLED == 0 )); then
        result fail "Er is niets geïnstalleerd, terwijl er $REPO_COUNT updates klaarstonden."
        [[ -n "$QUIET_TAIL" ]] && log_block "$(printf '%s\n' "$QUIET_TAIL" | sed 's/^/  /')"
        log "Probeer opnieuw met: kingstra update --interactief"
        return 1
    fi
    if (( rc != 0 )); then
        result fail "Arch/AUR eindigde met exitcode $rc ($TX_UPGRADED bijgewerkt voordat het stopte)."
        return "$rc"
    fi
    if (( n_left > 0 )); then
        result warn "$TX_UPGRADED pakketten bijgewerkt, maar $n_left staan nog open: $(inline_names "$remaining")"
        return 0
    fi
    if (( TX_UPGRADED + TX_INSTALLED == 0 )); then
        result ok "Arch/AUR was al actueel."
    else
        result ok "Arch/AUR bijgewerkt: $TX_UPGRADED pakketten nieuwer, $TX_INSTALLED nieuw."
    fi
}

# Na de update: draait de shell, staan de kernels op /boot, is er ruimte?
# Bij een echte fout bieden we meteen terugdraaien aan.
check_after_update() {
    local out="" rc=0
    if [[ -z "$HEALTH_CMD" ]]; then
        log "kingstra-health niet gevonden; controle overgeslagen."
        return 0
    fi
    out="$(bash "$HEALTH_CMD" --after-update 2>&1)" || rc=$?
    to_log "$out"
    case "$rc" in
        0) result ok "Controle na de update: alles in orde." ;;
        1) result warn "Controle na de update: let op."
           log_block "$(printf '%s\n' "$out" | grep -v '^OK' | sed 's/^/  /')" ;;
        *) result fail "Controle na de update vond een probleem."
           log_block "$(printf '%s\n' "$out" | grep -v '^OK' | sed 's/^/  /')"
           if [[ -n "$TX_FILE" && -n "$ROLLBACK_CMD" ]] && $UI \
               && ask_no "Deze update terugdraaien (pakketten naar de vorige versie)?"; then
               bash "$ROLLBACK_CMD" --system "$TX_FILE"
           fi ;;
    esac
}

# Uitkomst voor het update-venster in de shell.
write_result() {
    local code="$1"
    mkdir -p "$(dirname "$RESULT_FILE")" 2>/dev/null || return 0
    python3 -c '
import json, os, sys, time
path, code, log, tx, *rows = sys.argv[1:]
items = []
for row in rows:
    kind, _, rest = row.partition("|")
    step, _, text = rest.partition("|")
    items.append({"kind": kind, "step": step, "text": text})
with open(path + ".tmp", "w") as fh:
    json.dump({"time": int(time.time()), "exit": int(code), "log": log,
               "transaction": tx, "items": items}, fh, ensure_ascii=False)
os.replace(path + ".tmp", path)
' "$RESULT_FILE" "$code" "${LOG_FILE:-}" "${TX_FILE:-}" "${SUMMARY[@]+"${SUMMARY[@]}"}" 2>/dev/null || true
}

report_reboot() {
    command -v pacman >/dev/null 2>&1 || return 0
    if [[ -d "/usr/lib/modules/$(uname -r)" ]]; then
        result ok "Geen herstart nodig; de draaiende kernel is nog geïnstalleerd."
    else
        result warn "Herstart nodig: de draaiende kernel $(uname -r) is vervangen."
    fi
}

cleanup_system() {
    local orphans=""

    if command -v pacman >/dev/null 2>&1; then
        orphans="$(pacman -Qdtq 2>/dev/null || true)"
        if [[ -n "$orphans" ]]; then
            to_log "$orphans"
            log "Verweesde pakketten ($(count_lines "$orphans")): $(inline_names "$orphans")"
            if ask_no "Deze pakketten verwijderen?"; then
                # shellcheck disable=SC2086
                sudo pacman -Rns -- $orphans && log "Verweesde pakketten verwijderd."
            else
                log "Verweesde pakketten blijven staan."
            fi
        else
            log "Geen verweesde pakketten."
        fi
    fi

    if command -v paccache >/dev/null 2>&1; then
        if ask_no "Oude pakketcache opruimen (houdt de laatste 3 versies)?"; then
            # Drie versies: de huidige plus twee om naar terug te kunnen.
            # paccache meldt per run "finished: ..."; vat beide samen in één regel.
            local pc_out pc_saved
            if pc_out="$( { sudo paccache -rk3 && sudo paccache -ruk0; } 2>&1 )"; then
                pc_saved="$(sed -n 's/.*disk space saved: \([^)]*\)).*/\1/p' <<< "$pc_out" | paste -sd '+' -)"
                if [[ -n "$pc_saved" ]]; then
                    log "Pakketcache opgeruimd (vrijgemaakt: ${pc_saved//+/ + })."
                else
                    log "Pakketcache was al schoon."
                fi
            else
                result warn "Pakketcache opruimen lukte niet: $(tail -n 2 <<< "$pc_out" | tr '\n' ' ')"
            fi
        fi
    fi

    # yay ruimt zijn bouwcache nooit op; zonder dit groeit hij tot tientallen GB.
    if [[ -n "$AUR_CACHE_CMD" ]]; then
        local aur_free
        aur_free="$(bash "$AUR_CACHE_CMD" --size 2>/dev/null || true)"
        if [[ -n "$aur_free" && "$aur_free" != 0B ]]; then
            if ask_no "AUR-bouwcache opruimen ($aur_free vrij; houdt de laatste 3 builds)?"; then
                log "$(bash "$AUR_CACHE_CMD" --clean 2>&1)"
            fi
        fi
    fi

    if command -v flatpak >/dev/null 2>&1; then
        if ask_no "Ongebruikte Flatpak-runtimes verwijderen?"; then
            # Gepinde runtimes noemt flatpak altijd; dat is geen fout.
            local fp_out
            if fp_out="$(flatpak uninstall --unused -y 2>&1)"; then
                if grep -q 'Nothing unused' <<< "$fp_out"; then
                    log "Geen ongebruikte Flatpak-runtimes."
                else
                    log "Ongebruikte Flatpak-runtimes verwijderd."
                fi
            else
                result warn "Flatpak opruimen lukte niet: $(tail -n 2 <<< "$fp_out" | tr '\n' ' ')"
            fi
        fi
    fi

    # Elk extra pakket brengt zijn eigen updates mee; laat zien wat er
    # waarschijnlijk weg kan. Verwijderen gebeurt alleen per pakket na "j".
    if [[ -x "$AUDIT_SCRIPT" ]]; then
        live "Pakketoverzicht maken"
        log_block "$("$AUDIT_SCRIPT" --summary 2>/dev/null || true)"
        if ask_no "Kandidaten nu een voor een bekijken?"; then
            "$AUDIT_SCRIPT" --review
        else
            log "Later bekijken: $AUDIT_SCRIPT"
        fi
    fi
}

# -git-pakketten waarvan de AUR een hogere versie noemt dan de bron echt
# heeft (quickshell-games-launchers-git: AUR r138, bron r80). yay bouwt dan
# elke keer dezelfde versie opnieuw en de teller blijft op 1. Staat de
# geïnstalleerde commit gelijk aan die van de bron, dan slaan we hem over.
AUR_IGNORE=()
AUR_KEPT=""
drop_stale_git() {
    local list="$1" line name local_ver hash srcinfo src branch remote ref
    AUR_KEPT=""
    local cache="${XDG_CACHE_HOME:-$HOME/.cache}/yay"
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        name="${line%% *}"
        if [[ "$name" == *-git ]]; then
            local_ver="$(pacman -Q "$name" 2>/dev/null | awk '{print $2}')"
            hash="${local_ver%-*}"; hash="${hash##*.}"
            srcinfo="$cache/$name/.SRCINFO"
            if [[ "$hash" =~ ^g?[0-9a-f]{7,}$ && -f "$srcinfo" ]]; then
                hash="${hash#g}"
                src="$(sed -n 's/^[[:space:]]*source = //p' "$srcinfo" | grep -m1 'git+' || true)"
                src="${src#*::}"; src="${src#git+}"
                branch=""
                [[ "$src" == *"#branch="* ]] && branch="${src##*#branch=}"
                src="${src%%#*}"
                if [[ -n "$src" ]]; then
                    ref="HEAD"
                    [[ -n "$branch" ]] && ref="refs/heads/$branch"
                    remote="$(timeout 15 git ls-remote "$src" "$ref" 2>/dev/null | awk 'NR==1{print $1}')"
                    if [[ -n "$remote" && "$remote" == "$hash"* ]]; then
                        AUR_IGNORE+=("$name")
                        to_log "AUR: $name overgeslagen; geïnstalleerd $local_ver is al de nieuwste commit van de bron"
                        continue
                    fi
                fi
            fi
        fi
        AUR_KEPT+="$line"$'\n'
    done <<< "$list"
    AUR_KEPT="${AUR_KEPT%$'\n'}"
}

resolve_dotfiles_repo() {
    local marker="${XDG_DATA_HOME:-$HOME/.local/share}/kingstra/install-complete"
    local repo=""
    local script_path=""

    if [[ -f "$marker" ]]; then
        repo="$(sed -n 's/^Repo:[[:space:]]*//p' "$marker" | head -n 1)"
    fi
    if [[ -z "$repo" ]]; then
        script_path="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || true)"
        if [[ -n "$script_path" ]]; then
            repo="$(cd "$(dirname "$script_path")/../.." 2>/dev/null && pwd -P || true)"
        fi
    fi

    [[ -n "$repo" && -d "$repo/.git" ]] || return 1
    printf '%s\n' "$repo"
}

update_dotfiles() {
    local repo=""
    local branch=""
    local upstream=""
    local behind=0
    local ahead=0

    repo="$(resolve_dotfiles_repo 2>/dev/null || true)"
    if [[ -z "$repo" ]]; then
        log "Geen geïnstalleerde kingstra-dots git-repo gevonden; overgeslagen."
        return 0
    fi
    DOTFILES_REPO="$repo"

    # Na kingstra-rollback staan de dotfiles bewust vast.
    if [[ -f "$HOLD_FILE" ]]; then
        log "Dotfiles staan vast op $(cat "$HOLD_FILE") na een rollback; niet opgehaald."
        log "Weer meegaan met updates: kingstra-rollback --release"
        return 0
    fi

    branch="$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
    if [[ -z "$branch" ]]; then
        log "Dotfiles-repo staat niet op een branch; overgeslagen."
        return 0
    fi

    live "Dotfiles ophalen"
    if ! git -C "$repo" fetch --quiet origin "$branch"; then
        live_clear
        log "Dotfiles ophalen mislukt."
        return 1
    fi

    live_clear
    upstream="$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
    if [[ -z "$upstream" ]] && git -C "$repo" rev-parse --verify --quiet "origin/$branch" >/dev/null; then
        upstream="origin/$branch"
    fi
    if [[ -z "$upstream" ]]; then
        log "Geen upstream voor branch '$branch'; overgeslagen."
        return 0
    fi

    behind="$(git -C "$repo" rev-list --count "HEAD..$upstream" 2>/dev/null || echo 0)"
    ahead="$(git -C "$repo" rev-list --count "$upstream..HEAD" 2>/dev/null || echo 0)"
    if [[ "$behind" -eq 0 ]]; then
        log "Dotfiles zijn al actueel."
        return 0
    fi

    # Lokale commits die al op GitHub staan met een andere hash (bv. een
    # patch van de laptop die vanuit de cloud is gepusht) zijn geen eigen
    # werk meer: die mogen weg. Echt eigen commits houden de update tegen.
    local same_upstream=false unique=0
    if [[ "$ahead" -gt 0 ]]; then
        unique="$(git -C "$repo" cherry "$upstream" HEAD 2>/dev/null | grep -c '^+' || true)"
        if [[ "$unique" -eq 0 ]]; then
            same_upstream=true
            git -C "$repo" branch --force "kingstra-voor-update-$(date '+%Y%m%d-%H%M%S')" HEAD 2>/dev/null || true
            log "Je $ahead lokale commit(s) staan al op GitHub (zelfde wijziging, andere hash); lokaal gelijkgezet."
        else
            if [[ -z "$DOTFILES_SKIP" ]]; then
                DOTFILES_SKIP="$unique eigen commit(s) die niet op GitHub staan; dotfiles niet bijgewerkt"
                result warn "Dotfiles: $DOTFILES_SKIP."
            else
                log "Dotfiles: $DOTFILES_SKIP."
            fi
            log "Bekijk: git -C $repo log --oneline $upstream..HEAD  (push ze, of zet ze opzij)"
            return 0
        fi
    fi

    log "$behind nieuwe dotfiles-commit(s) gevonden."

    # Eigen wijzigingen in bijgehouden bestanden (bv. sneltoetsen of thema's
    # aangepast via Instellingen) gaan tijdelijk opzij en komen na de update
    # terug. Botsen ze met de update, dan blijft alles zoals het was. Losse
    # nieuwe bestanden laat git zelf met rust: merge --ff-only weigert als
    # zo'n bestand overschreven zou worden.
    local old_head stashed=false
    old_head="$(git -C "$repo" rev-parse HEAD)"
    if [[ -n "$(git -C "$repo" status --porcelain --untracked-files=no)" ]]; then
        log "Eigen wijzigingen gaan tijdelijk opzij:"
        log_block "$(git -C "$repo" status --short --untracked-files=no)"
        # Eigen naam voor de stash-commit: werkt ook zonder ingestelde git-identiteit.
        if ! git -C "$repo" -c user.name=kingstra -c user.email=kingstra@localhost stash push --quiet -m "kingstra-update $(date '+%Y-%m-%d %H:%M')"; then
            log "Opzij zetten mislukt; dotfiles-update veilig overgeslagen."
            return 0
        fi
        stashed=true
    fi

    if $same_upstream; then
        if ! git -C "$repo" reset --quiet --keep "$upstream"; then
            log "Gelijkzetten mislukt; dotfiles blijven op de oude stand."
            $stashed && git -C "$repo" stash pop --quiet
            return 1
        fi
    elif ! git -C "$repo" merge --ff-only --quiet "$upstream"; then
        log "Bijwerken mislukt; waarschijnlijk staat er een los bestand in de weg (zie hierboven)."
        $stashed && git -C "$repo" stash pop --quiet
        return 1
    fi

    if $stashed; then
        if git -C "$repo" stash apply --quiet 2>/dev/null; then
            git -C "$repo" stash drop --quiet
            log "Eigen wijzigingen teruggezet."
        else
            # Terug naar de stand van vóór de update, met de eigen wijzigingen.
            git -C "$repo" reset --quiet --hard HEAD
            git -C "$repo" reset --quiet --keep "$old_head"
            git -C "$repo" stash pop --quiet
            log "Eigen wijzigingen botsen met de update; dotfiles blijven op de oude stand."
            log "Bekijk met: git -C $repo diff"
            return 1
        fi
    fi
}

# Terugzetpunt vóór er iets verandert: git-tag van de dotfiles en, op btrfs
# met snapper, een systeemsnapshot. Mislukt dat, dan gaat de update door.
make_restore_point() {
    if [[ -z "$SNAPSHOT_CMD" || ! -f "$SNAPSHOT_CMD" ]]; then
        result warn "kingstra-snapshot niet gevonden; geen terugzetpunt."
        return 0
    fi
    if $UI && [[ "$(findmnt -no FSTYPE / 2>/dev/null)" == "btrfs" ]] \
        && command -v snapper >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1 \
        && ! sudo -n true 2>/dev/null; then
        live_clear
        sudo -v || true
    fi
    local out=""
    if out="$(bash "$SNAPSHOT_CMD" create "kingstra: voor update" 2>&1)"; then
        to_log "$out"
        result ok "Terugzetpunt gemaakt (terug met: kingstra-rollback)."
    else
        to_log "$out"
        result warn "Terugzetpunt maken mislukt; update gaat door."
    fi
}

run_dotfiles_installer() {
    local repo="$1"
    local installer="$repo/install.sh"

    if [[ ! -f "$installer" ]]; then
        log "Installer niet gevonden: $installer"
        return 1
    fi

    log "Installer bijwerken: pakketten, gegenereerde config en live reload."
    # 9>&-: de installer herstart de shell live; zonder dit erven quickshell en
    # co. de update-lock en zegt elke volgende run "draait al".
    KINGSTRA_UI_EMBEDDED=true bash "$installer" --yes 9>&-
}

# Bekende AUR-valkuilen vóór de build oplossen:
# - PGP: makers (Mozilla bij firefox-bin) tekenen met een nieuwe subsleutel;
#   de oude sleutel in je keyring kent die nog niet ("unknown public key").
#   We verversen de sleutels uit validpgpkeys van elk AUR-pakket met een update.
# - Afhankelijkheden die in de AUR-.SRCINFO ontbreken maar die de PKGBUILD
#   wel eist (skwd-daemon: qt6-tools). yay installeert die dan niet.
AUR_MISSING_DEPS=(
    "skwd-daemon:qt6-tools"
)
prepare_aur() {
    [[ -n "$AUR_LIST" ]] || return 0
    local name keys="" srcinfo entry pkg dep
    local -a deps=()
    local cache="${XDG_CACHE_HOME:-$HOME/.cache}"
    while read -r name _; do
        [[ -n "$name" ]] || continue
        for srcinfo in "$cache/yay/$name/.SRCINFO" "$cache/paru/clone/$name/.SRCINFO"; do
            [[ -f "$srcinfo" ]] || continue
            keys+=" $(awk -F' = ' '$1 ~ /validpgpkeys/ {print $2}' "$srcinfo" | tr '\n' ' ')"
        done
        for entry in "${AUR_MISSING_DEPS[@]}"; do
            pkg="${entry%%:*}" dep="${entry#*:}"
            [[ "$pkg" == "$name" ]] && ! pacman -Qq "$dep" >/dev/null 2>&1 && deps+=("$dep")
        done
    done <<< "$AUR_LIST"
    # shellcheck disable=SC2086  # bewust splitsen op spaties
    if [[ -n "${keys// /}" ]] && command -v gpg >/dev/null 2>&1; then
        live "PGP-sleutels voor AUR verversen"
        to_log "\$ gpg --refresh-keys$keys"
        timeout 60 gpg --keyserver hkps://keyserver.ubuntu.com --refresh-keys $keys >>"${LOG_FILE:-/dev/null}" 2>&1 \
            || timeout 60 gpg --refresh-keys $keys >>"${LOG_FILE:-/dev/null}" 2>&1 || true
    fi
    if (( ${#deps[@]} > 0 )); then
        live "Ontbrekende bouwpakketten: ${deps[*]}"
        to_log "\$ sudo pacman -S --needed --asdeps ${deps[*]}"
        # shellcheck disable=SC2024  # log is van de gebruiker, bewust
        sudo pacman -S --needed --noconfirm --asdeps "${deps[@]}" >>"${LOG_FILE:-/dev/null}" 2>&1 || true
    fi
    live_clear
}

# Repo-pakketten (waaronder de kernels) als losse systemd-dienst bijwerken.
# Op 10-11-2026 stopte pacman midden in een kernel-update, na het weghalen van
# de oude kernels van /boot en vóór het neerzetten van de nieuwe: de pc startte
# daarna niet meer. Een dienst hoort niet bij dit terminalvenster, dus sluiten
# (of een vastgelopen sessie) breekt pacman niet meer af. yay doet daarna alleen
# nog de AUR. Lukt dit niet (conflict, vraag), dan pakt yay het zoals vroeger.
PACMAN_UNIT="kingstra-pacman"
update_repo_detached() {
    command -v systemd-run >/dev/null 2>&1 || return 0
    command -v pacman >/dev/null 2>&1 || return 0
    wait_detached_pacman
    local rc=0 since n=0
    local -a buf=()
    since="$(date '+%Y-%m-%dT%H:%M:%S')"
    # stdbuf: anders houdt pacman zijn uitvoer in een buffer zolang hij niet
    # naar een terminal schrijft, en blijft de voortgangsregel minutenlang stil.
    command -v stdbuf >/dev/null 2>&1 && buf=(stdbuf -oL -eL)
    if (( REPO_COUNT > 0 )); then
        log "$REPO_COUNT systeempakket(ten) via pacman. Loopt als losse dienst: dit venster sluiten breekt het niet af."
    else
        log "Geen systeemupdates gevonden; pacman kijkt het nog even na."
    fi
    QUIET_DETACHED=true
    run_quiet "pacman" sudo systemd-run --quiet --wait --pipe --collect \
        --unit="$PACMAN_UNIT" --description="Kingstra update (pacman)" \
        "${buf[@]+"${buf[@]}"}" pacman -Syu --noconfirm || rc=$?
    QUIET_DETACHED=false
    n="$(count_pacman_changes "$since")"
    if (( rc != 0 )); then
        result warn "pacman stopte met code $rc ($n pakketten al bijgewerkt); yay probeert de rest in de volgende stap."
    elif (( n == 0 )); then
        result ok "Systeempakketten waren al actueel."
    else
        result ok "Systeempakketten bijgewerkt: $n."
    fi
    return 0
}

# Aantal upgraded/installed-regels in pacman.log sinds $1.
count_pacman_changes() {
    [[ -r "$PACMAN_LOG" ]] || { printf '0'; return 0; }
    awk -v since="$1" '
        /^\[[0-9]{4}-[0-9]{2}-[0-9]{2}T[^]]*\] \[ALPM\] (upgraded|installed|downgraded) / {
            if (substr($1, 2, 19) >= since) n++
        }
        END { print n + 0 }' "$PACMAN_LOG" 2>/dev/null || printf '0'
}

# Een pacman-dienst van een eerder (gesloten) venster mag eerst afmaken.
wait_detached_pacman() {
    command -v systemctl >/dev/null 2>&1 || return 0
    systemctl is-active --quiet "$PACMAN_UNIT.service" 2>/dev/null || return 0
    result warn "Een eerdere update is nog bezig met pakketten installeren; even wachten tot die klaar is."
    while systemctl is-active --quiet "$PACMAN_UNIT.service" 2>/dev/null; do
        live "Wachten op de lopende pacman-update"
        sleep 1
    done
    live_clear
}

# Ontbreekt een kernel op /boot (afgebroken update), dan start de pc niet meer.
# pacman -S zet de kernel én de mkinitcpio-preset terug en bouwt de initramfs;
# mkinitcpio -P alleen helpt niet als de preset ook weg is.
repair_missing_kernels() {
    command -v pacman >/dev/null 2>&1 || return 0
    local boot="${KINGSTRA_BOOT_DIR:-/boot}" k missing=()
    for k in $(pacman -Qq linux linux-lts linux-zen linux-hardened 2>/dev/null); do
        if [[ -r "$boot" && -x "$boot" ]]; then
            [[ -f "$boot/vmlinuz-$k" ]] || missing+=("$k")
        elif sudo -n true 2>/dev/null; then
            sudo -n test -f "$boot/vmlinuz-$k" || missing+=("$k")
        fi
    done
    (( ${#missing[@]} > 0 )) || return 0
    result fail "Kernel ontbreekt op $boot: ${missing[*]}. Zo start de pc niet meer op."
    if ask_yes "Nu terugzetten (sudo pacman -S ${missing[*]})?"; then
        if sudo pacman -S --noconfirm "${missing[@]}" >>"${LOG_FILE:-/dev/null}" 2>&1; then
            result ok "Kernel(s) teruggezet: ${missing[*]}."
        else
            result fail "Terugzetten mislukt; zie het log. Draai zelf: sudo pacman -S ${missing[*]}"
        fi
    fi
}

# Stap "Systeempakketten": de officiële repo's (met de kernel) via pacman als
# dienst. Zonder terminal of met --interactief doet yay dit in de AUR-stap.
update_system() {
    if ! $UI || $INTERACTIVE; then
        log "Gaat in één keer mee met yay in de volgende stap."
        return 0
    fi
    # Wachtwoord nu vragen, zodat de stille run niet op sudo blijft hangen.
    if command -v sudo >/dev/null 2>&1 && ! sudo -n true 2>/dev/null; then
        live_clear
        log "Wachtwoord nodig voor de pakketupdate:"
        sudo -v || return 1
    fi
    update_repo_detached
}

# yay/paru en flatpak bijwerken. In de compacte weergave stil met
# voortgangsbalk; mislukt dat, dan kan de run interactief opnieuw.
update_arch() {
    local helper="" rc=0
    if command -v yay >/dev/null 2>&1; then
        helper="yay"
    elif command -v paru >/dev/null 2>&1; then
        helper="paru"
    else
        result warn "Geen yay of paru gevonden; overgeslagen."
        return 0
    fi

    local -a ignore=()
    if (( ${#AUR_IGNORE[@]} > 0 )); then
        ignore=(--ignore "$(IFS=,; echo "${AUR_IGNORE[*]}")")
    fi
    if ! $UI || $INTERACTIVE; then
        prepare_aur
        "$helper" -Syu "${ignore[@]+"${ignore[@]}"}" || rc=$?
        return "$rc"
    fi

    local -a flags=(-Syu --noconfirm --sudoloop "${ignore[@]+"${ignore[@]}"}")
    case "$helper" in
        yay) flags+=(--answerdiff None --answerclean None --answeredit None --answerupgrade None) ;;
        paru) flags+=(--skipreview) ;;
    esac
    if command -v sudo >/dev/null 2>&1 && ! sudo -n true 2>/dev/null; then
        live_clear
        sudo -v || return 1
    fi
    prepare_aur
    if (( AUR_COUNT > 0 )); then
        log "$AUR_COUNT AUR-pakket(ten) bouwen en installeren met $helper: $(inline_names "$AUR_LIST")"
    else
        log "Geen AUR-updates; $helper controleert alleen nog of alles klopt."
    fi
    PROG_EXPECT="$AUR_COUNT"
    run_quiet "$helper" "$helper" "${flags[@]}" || rc=$?
    PROG_EXPECT=""
    if (( rc != 0 )) && ask_yes "Opnieuw draaien met de gewone $helper-uitvoer en vragen?"; then
        rc=0
        "$helper" -Syu "${ignore[@]+"${ignore[@]}"}" || rc=$?
    fi
    return "$rc"
}

update_flatpak() {
    local rc=0
    if ! $UI || $INTERACTIVE; then
        flatpak update || rc=$?
        return "$rc"
    fi
    run_quiet "Flatpak" flatpak update -y --noninteractive || rc=$?
    return "$rc"
}

finish() {
    local code="$1" line kind title msg glyph color
    write_result "$code"
    rm -f "$PROGRESS_FILE" 2>/dev/null
    if $UI; then
        live_clear
        printf '\n  %s%s%s %s100%%%s  %sKlaar%s %sin %s%s\n' "$C_GREEN" "$(bar 1 1 14)" "$C_RESET" "$C_BOLD" "$C_RESET" "$C_BOLD" "$C_RESET" "$C_DIM" "$(elapsed_since "$RUN_T0")" "$C_RESET"
        printf '\033]2;Kingstra update · klaar\007'
        for line in "${SUMMARY[@]+"${SUMMARY[@]}"}"; do
            IFS='|' read -r kind title msg <<< "$line"
            [[ "$kind" == "ok" ]] && continue
            case "$kind" in
                warn) glyph="$G_WARN"; color="$C_YELLOW" ;;
                *) glyph="$G_FAIL"; color="$C_RED" ;;
            esac
            printf '    %s%s%s %s%s:%s %s\n' "$color" "$glyph" "$C_RESET" "$C_DIM" "$title" "$C_RESET" "$msg"
        done
    else
        section "Klaar"
    fi
    if [[ $code -eq 0 && "$MODE" == "dotfiles" ]]; then
        log "Dotfiles verwerkt; pakketten zijn niet bijgewerkt (daarvoor: kingstra update alles)."
    elif [[ $code -eq 0 ]]; then
        log "Alle beschikbare updatebronnen zijn verwerkt."
    else
        log "Minstens één updatebron eindigde met een fout (code $code)."
    fi
    [[ -n "$LOG_FILE" ]] && log "${C_DIM}Log: $LOG_FILE${C_RESET}"
    echo
    live_clear
    read -r -p "Druk Enter om te sluiten..." _
}

# Proefdraai: wat de echte update zou tegenhouden, vooraf en zonder wijzigingen.
CHECK_WARNS=0
check_warn() { CHECK_WARNS=$((CHECK_WARNS + 1)); result warn "$1"; }

run_check() {
    local avail boot_avail kernel_update=false repo upstream branch ahead behind unique
    local hypr_new dirty incoming clash f bad_syntax="" pkg dep missing

    # Ruimte: yay bouwt in ~/.cache, mkinitcpio schrijft naar /boot.
    avail="$(df -Pm / 2>/dev/null | awk 'NR==2 {print $4}')"
    if [[ -n "$avail" && "$avail" -lt 3072 ]]; then
        check_warn "Weinig ruimte op /: $((avail / 1024)) GB vrij; AUR-builds en de pakketcache hebben meer nodig."
    else
        result ok "Ruimte op /: $((${avail:-0} / 1024)) GB vrij."
    fi
    printf '%s\n' "$REPO_LIST" | grep -qE '^linux(-lts|-zen|-hardened)? ' && kernel_update=true
    boot_avail="$(df -Pm /boot 2>/dev/null | awk 'NR==2 {print $4}')"
    if $kernel_update && [[ -n "$boot_avail" && "$boot_avail" -lt 150 ]]; then
        check_warn "Kernel-update met maar ${boot_avail} MB vrij op /boot; nieuwe initramfs past mogelijk niet."
    elif [[ -n "$boot_avail" ]]; then
        result ok "Ruimte op /boot: ${boot_avail} MB vrij."
    fi

    # Hyprland-update: bouwt de zoom-plugin straks nog? Vraag het de versie van
    # het bouwscript die de update gaat ophalen.
    repo="$(resolve_dotfiles_repo 2>/dev/null || true)"
    branch="$( [[ -n "$repo" ]] && git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
    upstream=""
    if [[ -n "$repo" && -n "$branch" ]]; then
        live "Dotfiles ophalen (alleen kijken)"
        if git -C "$repo" fetch --quiet origin "$branch" 2>/dev/null; then
            upstream="origin/$branch"
        else
            check_warn "Dotfiles ophalen lukte niet (netwerk of GitHub)."
        fi
        live_clear
    fi
    hypr_new="$(printf '%s\n' "$REPO_LIST" | awk '$1 == "hyprland" {print $NF}' | sed 's/-[0-9]*$//')"
    if [[ -n "$hypr_new" ]]; then
        if [[ -n "$upstream" ]] && git -C "$repo" show "$upstream:config/shared/scripts/kingstra-build-native-zoom" 2>/dev/null \
                | bash -s -- --supports "$hypr_new"; then
            result ok "Hyprland $hypr_new: zoom-plugin wordt ervoor gebouwd."
        else
            check_warn "Hyprland $hypr_new: de zoom-plugin kent deze versie nog niet. Na de update werken knijpzoomen en meeschuiven niet tot dat is bijgewerkt."
        fi
    fi

    # Dotfiles: kunnen ze straks netjes mee?
    if [[ -n "$upstream" ]]; then
        if [[ -f "$HOLD_FILE" ]]; then
            check_warn "Dotfiles staan vast na een rollback; ze worden niet bijgewerkt (kingstra-rollback --release)."
        fi
        behind="$(git -C "$repo" rev-list --count "HEAD..$upstream" 2>/dev/null || echo 0)"
        ahead="$(git -C "$repo" rev-list --count "$upstream..HEAD" 2>/dev/null || echo 0)"
        if [[ "$ahead" -gt 0 ]]; then
            unique="$(git -C "$repo" cherry "$upstream" HEAD 2>/dev/null | grep -c '^+' || true)"
            if [[ "$unique" -gt 0 ]]; then
                check_warn "$unique eigen dotfiles-commit(s) staan niet op GitHub; de update haalt dan niets op. Push ze eerst."
            else
                result ok "Lokale commit(s) staan al op GitHub; de update zet ze gelijk."
            fi
        fi
        dirty="$(git -C "$repo" diff --name-only HEAD 2>/dev/null)"
        incoming="$(git -C "$repo" diff --name-only HEAD "$upstream" 2>/dev/null)"
        clash="$(comm -12 <(sort -u <<< "$dirty") <(sort -u <<< "$incoming") | grep . || true)"
        if [[ -n "$clash" ]]; then
            check_warn "Eigen wijziging in een bestand dat de update ook verandert: $(inline_names "$clash"). Lukt samenvoegen niet, dan blijven de dotfiles op de oude stand."
        elif [[ "$behind" -gt 0 ]]; then
            result ok "Dotfiles: $behind nieuwe commit(s), geen botsing met eigen wijzigingen."
        else
            result ok "Dotfiles zijn al actueel."
        fi
        # Syntaxcheck van de installer zoals hij straks draait.
        for f in $(git -C "$repo" ls-tree --name-only "$upstream" installer/phases/ installer/lib/ 2>/dev/null | grep '\.sh$'); do
            git -C "$repo" show "$upstream:$f" 2>/dev/null | bash -n 2>/dev/null || bad_syntax+="$f "
        done
        if [[ -n "$bad_syntax" ]]; then
            check_warn "Installer-scripts met een syntaxfout in de nieuwe versie: $bad_syntax"
        else
            result ok "Installer van de nieuwe versie: geen syntaxfouten."
        fi
    fi

    # AUR: afhankelijkheden die nergens meer bestaan (zoals whisper.cpp).
    if [[ -n "$AUR_LIST" ]] && command -v yay >/dev/null 2>&1; then
        live "AUR-pakketten nalopen"
        missing=""
        while read -r pkg _; do
            [[ -n "$pkg" ]] || continue
            for dep in $(timeout 30 yay -Si --aur "$pkg" 2>/dev/null \
                    | awk -F': ' '/^(Depends On|Make Deps)/ {print $2}' | tr ' ' '\n' \
                    | grep -v '^None$' | sed 's/[<>=].*//' | sort -u); do
                pacman -T "$dep" >/dev/null 2>&1 && continue
                pacman -Si "$dep" >/dev/null 2>&1 && continue
                pacman -Ssq "^${dep}$" >/dev/null 2>&1 && continue
                timeout 20 yay -Si --aur "$dep" >/dev/null 2>&1 && continue
                missing+="$pkg→$dep "
            done
        done <<< "$AUR_LIST"
        live_clear
        if [[ -n "$missing" ]]; then
            check_warn "AUR-pakketten met een afhankelijkheid die nergens te vinden is: $missing(die bouw mislukt; de rest gaat door)."
        else
            result ok "AUR: alle afhankelijkheden te vinden."
        fi
    fi

    # Wat nu al openstaat en de update moeilijker maakt.
    local pacnew
    pacnew="$(find /etc -name '*.pacnew' 2>/dev/null | wc -l)"
    [[ "$pacnew" -gt 0 ]] && check_warn "Er staan al $pacnew .pacnew-bestand(en) open; de update vraagt ze na."
    if command -v pacman >/dev/null 2>&1 && [[ ! -d "/usr/lib/modules/$(uname -r)" ]]; then
        check_warn "Er staat nog een herstart open van de vorige update; doe die eerst."
    fi
    if systemctl --failed --no-legend 2>/dev/null | grep -q .; then
        check_warn "Mislukte diensten: $(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}' | paste -sd ' ' -)"
    fi

    if [[ $CHECK_WARNS -eq 0 ]]; then
        result ok "Niets gevonden dat de update tegenhoudt. Bijwerken: kingstra update"
    else
        log "$CHECK_WARNS punt(en) om op te letten; er is niets geïnstalleerd of veranderd."
    fi
}

# Na een afgebroken update (terminal dicht, laptop in slaap, stroom weg):
# zeggen waar hij stopte en de restjes opruimen die de volgende run blokkeren.
# De stappen zelf zijn veilig om opnieuw te draaien; wat al klaar was gaat snel.
resume_after_abort() {
    local when step oldlog age
    if [[ -f "$PROGRESS_FILE" ]]; then
        IFS=$'\t' read -r when step oldlog < "$PROGRESS_FILE" || true
        age=$(( $(date +%s) - ${when:-0} ))
        if [[ "$when" =~ ^[0-9]+$ ]] && (( age < 14 * 86400 )); then
            result warn "De vorige update stopte bij \"$step\" ($(date -d "@$when" '+%d-%m %H:%M')). Hij loopt nu opnieuw; wat al klaar was gaat snel."
            [[ -n "$oldlog" && -f "$oldlog" ]] && log "${C_DIM}Log van toen: $oldlog${C_RESET}"
        fi
        rm -f "$PROGRESS_FILE"
    fi
    # Een achtergebleven pacman-slot zonder pacman erachter houdt yay tegen
    # ("unable to lock database").
    wait_detached_pacman
    if [[ -e /var/lib/pacman/db.lck ]] && ! pgrep -x pacman >/dev/null 2>&1 && ! pgrep -x yay >/dev/null 2>&1; then
        result warn "Pacman-slot van een afgebroken update gevonden (/var/lib/pacman/db.lck)."
        if ask_yes "Slot weghalen? (er draait geen pacman)"; then
            sudo rm -f /var/lib/pacman/db.lck && log "Slot weggehaald."
        fi
    fi
    repair_missing_kernels
}

# Keuzemenu: alles of alleen de dotfiles (of een proefdraai). Komt na het
# ophalen van de nieuwe updater, zodat het menu zelf ook altijd actueel is.
# Zonder terminal of met een keuze op de opdrachtregel: geen vraag.
choose_mode() {
    $CHECK && return 0
    if [[ -n "$MODE" ]]; then
        return 0
    fi
    if [[ ! -t 0 ]]; then
        # Geen terminal om te vragen: nooit stilzwijgend een systeemupdate.
        MODE="stop"
        STOP_REASON="Geen keuze opgegeven en geen terminal om te vragen. Gebruik: kingstra update alles  of  kingstra update dotfiles"
        return 0
    fi
    local ts=0 total=0 pkgs=0 flat=0 _d _c sys_hint="" dot_hint="" repo reply=""
    local cache="$CACHE_DIR/package_updates_status"
    if [[ -f "$cache" ]]; then
        read -r ts total pkgs flat _d _c < "$cache" || true
    fi
    if [[ "$ts" =~ ^[0-9]+$ && "$pkgs" =~ ^[0-9]+$ && "$flat" =~ ^[0-9]+$ ]] && (( ts > 0 )); then
        sys_hint="$pkgs pakketten, $flat Flatpak (geteld om $(date -d "@$ts" '+%H:%M' 2>/dev/null))"
    fi
    repo="$(resolve_dotfiles_repo 2>/dev/null || true)"
    if [[ "${KINGSTRA_UPDATE_REEXEC:-}" =~ ^[0-9a-f]{7,}$ && -n "$repo" ]]; then
        dot_hint="$(git -C "$repo" rev-list --count "$KINGSTRA_UPDATE_REEXEC..HEAD" 2>/dev/null || echo '?') nieuwe commit(s) net opgehaald"
    elif [[ -n "$repo" ]]; then
        dot_hint="al actueel ($(git -C "$repo" log -1 --date=format:'%d-%m %H:%M' --format='%h van %cd' 2>/dev/null))"
    fi

    live_clear
    printf '\n  %sWat wil je bijwerken?%s\n\n' "$C_BOLD" "$C_RESET"
    printf '    %s1%s  %sAlles%s            systeem, AUR, Flatpak en dotfiles\n' "$C_CYAN" "$C_RESET" "$C_BOLD" "$C_RESET"
    [[ -n "$sys_hint" ]] && printf '                        %s%s%s\n' "$C_DIM" "$sys_hint" "$C_RESET"
    printf '    %s2%s  %sAlleen dotfiles%s  config, shell en scripts; geen pakketupdates (snel)\n' "$C_CYAN" "$C_RESET" "$C_BOLD" "$C_RESET"
    [[ -n "$dot_hint" ]] && printf '                        %s%s%s\n' "$C_DIM" "$dot_hint" "$C_RESET"
    printf '    %s3%s  %sProefdraai%s       kijken wat een update zou tegenhouden; niets installeren\n' "$C_CYAN" "$C_RESET" "$C_BOLD" "$C_RESET"
    printf '    %sq%s  Stoppen\n\n' "$C_CYAN" "$C_RESET"
    read -r -p "    ${C_CYAN}${G_ASK}${C_RESET} Keuze ${C_DIM}[1]${C_RESET} " reply || reply="1"
    case "${reply,,}" in
        ""|1|a|alles) MODE="alles" ;;
        2|d|dotfiles) MODE="dotfiles" ;;
        3|p|proef*) CHECK=true ;;
        *) MODE="stop" ;;
    esac
}

# Wat er in deze run gaat gebeuren, in één regel.
show_plan() {
    local plan=""
    if $CHECK; then
        STEPS_TOTAL=3
        plan="Arch-nieuws · Wat er bijwerkt · Proefdraai (niets installeren)"
    elif [[ "$MODE" == "dotfiles" ]]; then
        STEPS_TOTAL=2
        plan="Dotfiles + installer · Controle (geen pakketupdates)"
    else
        STEPS_TOTAL=10
        plan="Arch-nieuws · Wat er bijwerkt · Terugzetpunt · Systeempakketten · AUR · Flatpak · Dotfiles · Na de update · Controle · Opruimen"
    fi
    to_log "Keuze: $($CHECK && echo proefdraai || echo "$MODE")" "Plan: $plan"
    if $UI; then
        printf '  %sPlan:%s %s%s%s\n' "$C_DIM" "$C_RESET" "$C_DIM" "$plan" "$C_RESET"
    else
        printf 'Plan: %s\n' "$plan"
    fi
}

# Dotfiles ophalen en de installer draaien (in beide modi gelijk).
run_dotfiles_step() {
    section "Dotfiles"
    dotfiles_update_exit=0
    update_dotfiles || dotfiles_update_exit=$?
    if [[ "${KINGSTRA_UPDATE_REEXEC:-}" =~ ^[0-9a-f]{7,}$ && -n "$DOTFILES_REPO" ]]; then
        log "Aan het begin opgehaald: ${KINGSTRA_UPDATE_REEXEC:0:7} → $(git -C "$DOTFILES_REPO" rev-parse --short HEAD 2>/dev/null)."
        log_block "$(git -C "$DOTFILES_REPO" log --format='  %h %s' "$KINGSTRA_UPDATE_REEXEC..HEAD" 2>/dev/null | head -n 8)"
    fi

    # Een git pull alleen is niet genoeg: nieuwe pakketten, gegenereerde hardware-
    # config en live sessiewijzigingen worden pas door install.sh toegepast. Draai
    # de installer ook als de repo al actueel is, zodat een eerdere half-afgeronde
    # update zichzelf kan herstellen.
    installer_exit=0
    if [[ -n "$DOTFILES_REPO" ]]; then
        run_dotfiles_installer "$DOTFILES_REPO" || installer_exit=$?
        [[ $installer_exit -eq 0 ]] || overall_exit=1
    fi

    if [[ $dotfiles_update_exit -ne 0 ]]; then
        overall_exit=1
    fi

    if [[ $dotfiles_update_exit -ne 0 || $installer_exit -ne 0 ]]; then
        result fail "Dotfiles: ophalen of installer mislukt (code $dotfiles_update_exit/$installer_exit)."
    elif [[ -n "$DOTFILES_SKIP" ]]; then
        : # al als waarschuwing gemeld
    else
        result ok "Dotfiles bijgewerkt."
    fi
}

# Eén update tegelijk. Twee runs naast elkaar (terminal plus het venster uit
# Instellingen) wachten op elkaars sudo, git en installer.
LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/kingstra-update.lock"
if command -v flock >/dev/null 2>&1 && exec 9>"$LOCK_FILE"; then
    # Lock bezet maar geen updater actief: een kindproces (bv. een shell die
    # een oudere updater live herstartte) houdt hem vast. Dan gewoon door.
    if ! flock -n 9 && ! pgrep -f 'package_upgrade\.sh' | grep -qvxE "$$|$PPID"; then
        echo "  (Oude update-lock zonder lopende update genegeerd.)"
    elif ! flock -n 9; then
        echo
        echo "  Er draait al een kingstra update (in een ander venster of een gestopte terminal)."
        echo "  Maak die eerst af of sluit hem. Vastgelopen? pkill -f package_upgrade.sh"
        echo
        if [[ -t 0 ]]; then read -r -p "Druk Enter om te sluiten..." _ || true; fi
        exit 1
    fi
fi

init_log
RUN_T0="${KINGSTRA_UPDATE_T0:-$(date +%s)}"

if $UI; then
    printf '\033]2;Kingstra update\007'
    printf '\n  %sKingstra Update Runner%s  %spacman %s yay %s Flatpak %s kingstra-dots%s\n' \
        "$C_BOLD" "$C_RESET" "$C_DIM" "$G_DOT" "$G_DOT" "$G_DOT" "$C_RESET"
else
    echo "=============================================="
    echo " Kingstra Update Runner"
    echo " pacman · yay · Flatpak · kingstra-dots"
    echo "=============================================="
fi
to_log "Gestart: $(date '+%Y-%m-%d %H:%M:%S')"

# Eerst de dotfiles ophalen en dan met de nieuwe updater verder. Anders
# draaien Arch/AUR, configbestanden en de controle nog met de code van vóór
# de update, en werken fixes pas bij de keer daarna.
if $CHECK; then
    : # proefdraai: niets ophalen of veranderen
elif [[ -z "${KINGSTRA_UPDATE_REEXEC:-}" ]]; then
    self_before="$(git -C "$(resolve_dotfiles_repo 2>/dev/null || echo /nonexistent)" rev-parse HEAD 2>/dev/null || true)"
    live "Nieuwste versie van de updater en dotfiles ophalen"
    # Stil: wat er gebeurt staat in het log en komt bij Dotfiles terug.
    if [[ -n "$self_before" ]] && update_dotfiles >/dev/null; then
        self_after="$(git -C "$DOTFILES_REPO" rev-parse HEAD 2>/dev/null || true)"
        # update_dotfiles wiste zijn eigen regel in /dev/null; deze nog niet.
        LIVE_SHOWN=true
        live_clear
        if [[ -n "$self_after" && "$self_after" != "$self_before" && -f "$SELF" ]]; then
            log "Dotfiles bijgewerkt (${self_before:0:7} → ${self_after:0:7}); verder met de nieuwe updater."
            export KINGSTRA_UPDATE_REEXEC="$self_before" KINGSTRA_UPDATE_LOG="$LOG_FILE" KINGSTRA_UPDATE_T0="$RUN_T0"
            exec bash "$SELF" "${ORIG_ARGS[@]+"${ORIG_ARGS[@]}"}"
        fi
    fi
    LIVE_SHOWN=true
    live_clear
    DOTFILES_REPO=""
elif [[ "$KINGSTRA_UPDATE_REEXEC" =~ ^[0-9a-f]{7,}$ ]]; then
    to_log "Opnieuw gestart na dotfiles-update vanaf $KINGSTRA_UPDATE_REEXEC"
fi

STOP_REASON=""
choose_mode
if [[ "$MODE" == "stop" ]]; then
    printf '\n'
    log "Niets bijgewerkt.${STOP_REASON:+ $STOP_REASON}"
    [[ -n "$LOG_FILE" ]] && to_log "Gestopt bij het keuzemenu."
    exit 0
fi
show_plan

if ! $CHECK && [[ -z "${KINGSTRA_UPDATE_REEXEC:-}" || "${KINGSTRA_UPDATE_REEXEC}" =~ ^[0-9a-f]{7,}$ ]]; then
    resume_after_abort
fi

# Alleen dotfiles: geen nieuws, pakketlijst, terugzetpunt of opruimen.
if [[ "$MODE" == "dotfiles" ]] && ! $CHECK; then
    run_dotfiles_step
    section "Controle"
    check_after_update
    # Teller in de balk bijwerken zonder hierop te wachten.
    ( "$COUNT_SCRIPT" --refresh >/dev/null 2>&1 9>&- & )
    finish "$overall_exit"
    exit "$overall_exit"
fi

section "Arch-nieuws"
if ! check_arch_news; then
    rm -f "$PROGRESS_FILE" 2>/dev/null
    [[ -n "$LOG_FILE" ]] && log "Log: $LOG_FILE"
    live_clear
    read -r -p "Druk Enter om te sluiten..." _
    exit 0
fi

section "Wat er bijwerkt"
preview_updates
if $CHECK; then
    section "Proefdraai"
    run_check
    echo
    [[ -n "$LOG_FILE" ]] && log "${C_DIM}Log: $LOG_FILE${C_RESET}"
    live_clear
    $UI && { read -r -p "Druk Enter om te sluiten..." _ || true; }
    exit 0
fi
if $UI && ! $INTERACTIVE && (( REPO_COUNT + AUR_COUNT + FLATPAK_COUNT > 0 )); then
    if ! ask_yes "Updates installeren?"; then
        if ask_yes "Dan alleen de dotfiles bijwerken?"; then
            MODE="dotfiles"
            STEPS_TOTAL=$((STEP_NUM + 2))
            run_dotfiles_step
            section "Controle"
            check_after_update
            finish "$overall_exit"
            exit "$overall_exit"
        fi
        log "Update op verzoek gestopt."
        finish 0
        exit 0
    fi
fi

section "Terugzetpunt"
make_restore_point

section "Systeempakketten"
arch_exit=0
arch_since="$(date '+%Y-%m-%dT%H:%M:%S')"
update_system || arch_exit=$?

section "AUR"
if [[ $arch_exit -eq 0 ]]; then
    update_arch || arch_exit=$?
else
    log "Overgeslagen: geen sudo voor de pakketupdate."
fi
if ! verify_arch "$arch_since" "$arch_exit"; then
    [[ $arch_exit -eq 0 ]] && arch_exit=1
fi
[[ $arch_exit -eq 0 ]] || overall_exit=$arch_exit

section "Flatpak"
flatpak_exit=0
if command -v flatpak >/dev/null 2>&1; then
    (( FLATPAK_COUNT > 0 )) && log "$FLATPAK_COUNT Flatpak-update(s)."
    update_flatpak || flatpak_exit=$?
    if [[ $flatpak_exit -eq 0 ]]; then
        result ok "Flatpak bijgewerkt."
    else
        result fail "Flatpak eindigde met exitcode $flatpak_exit."
    fi
else
    log "Flatpak is niet geïnstalleerd; overgeslagen."
fi
[[ $flatpak_exit -eq 0 ]] || overall_exit=$flatpak_exit

run_dotfiles_step

section "Na de update"
report_pacnew
report_reboot

section "Controle"
check_after_update

section "Opruimen"
cleanup_system

if [[ $arch_exit -eq 0 ]]; then
    mkdir -p "$STATE_DIR" 2>/dev/null && date +%s > "$LAST_RUN_FILE"
fi

mkdir -p "$CACHE_DIR"
rm -f "$CACHE_DIR/package_updates_status" "$CACHE_DIR/package_updates_count"
"$COUNT_SCRIPT" --refresh >/dev/null 2>&1 9>&- || true

finish "$overall_exit"
exit "$overall_exit"
