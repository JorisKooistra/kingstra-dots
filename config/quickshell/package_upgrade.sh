#!/usr/bin/env bash
# Kingstra Update Runner: Arch-nieuws, Arch/AUR, Flatpak en dotfiles in één run.
# In een terminal toont het per stap een korte samenvatting en een
# voortgangsbalk; de volledige uitvoer van yay/flatpak gaat naar het log.
# --interactief geeft yay en flatpak weer hun eigen uitvoer en vragen.
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
[[ "${1:-}" == "--interactief" || "${1:-}" == "--interactive" ]] && INTERACTIVE=true

# ---------------------------------------------------------------------------
# Weergave
# ---------------------------------------------------------------------------
UI=false
[[ -t 0 && -t 1 && "${TERM:-}" != "dumb" ]] && UI=true

STEPS_TOTAL=9
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

# Eén regel die steeds overschreven wordt: spinner, optionele balk, tekst.
live() {
    $UI || return 0
    local msg="$1" done="${2:-}" total="${3:-}" prefix plain max
    local spin="${SPIN[SPIN_IDX % ${#SPIN[@]}]}"
    SPIN_IDX=$((SPIN_IDX + 1))
    if [[ -n "$total" && "$total" -gt 0 ]]; then
        plain="    $spin $(bar "$total" "$done" 20) $done/$total  "
        prefix="    ${C_CYAN}${spin}${C_RESET} ${C_GREEN}$(bar "$total" "$done" 20)${C_RESET} ${C_BOLD}${done}/${total}${C_RESET}  "
    else
        plain="    $spin "
        prefix="    ${C_CYAN}${spin}${C_RESET} "
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
    if $UI; then
        live_clear
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

# Draait een commando stil: uitvoer naar het log, in de terminal een
# voortgangsregel. Tellers als "( 3/87) upgrading foo" van pacman worden
# een balk; anders staat de laatste uitvoerregel achter de spinner.
run_quiet() {
    local label="$1"
    shift
    local tmp rc=0 last="" counter="" done="" total="" text=""
    QUIET_TAIL=""
    tmp="$(mktemp)"
    to_log "\$ $*"
    "$@" </dev/null >"$tmp" 2>&1 &
    local pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        last="$(tail -n 30 "$tmp" 2>/dev/null | tr '\r' '\n' | sed 's/\x1b\[[0-9;]*[A-Za-z]//g' | awk 'NF' | tail -n 1)"
        counter="$(tail -n 60 "$tmp" 2>/dev/null | tr '\r' '\n' | grep -E '^\( *[0-9]+/[0-9]+\) ' | tail -n 1)"
        done="" total=""
        if [[ "$counter" =~ ^\(\ *([0-9]+)/([0-9]+)\)\ +(.*)$ ]]; then
            done="${BASH_REMATCH[1]}" total="${BASH_REMATCH[2]}" text="${BASH_REMATCH[3]}"
            live "$label: $text" "$done" "$total"
        else
            live "$label${last:+: $last}"
        fi
        sleep 0.15
    done
    wait "$pid" || rc=$?
    [[ -n "$LOG_FILE" ]] && cat "$tmp" >> "$LOG_FILE"
    QUIET_TAIL="$(tr '\r' '\n' < "$tmp" | sed 's/\x1b\[[0-9;]*[A-Za-z]//g' | awk 'NF' | tail -n 8)"
    live_clear
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
            sudo paccache -rk3 && sudo paccache -ruk0 && log "Pakketcache opgeruimd."
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
            flatpak uninstall --unused -y && log "Ongebruikte Flatpak-runtimes verwijderd."
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

    if [[ "$ahead" -gt 0 ]]; then
        log "De lokale branch loopt ook $ahead commit(s) voor op upstream."
        log "Automatisch samenvoegen is overgeslagen."
        return 0
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

    if ! git -C "$repo" merge --ff-only --quiet "$upstream"; then
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
    KINGSTRA_UI_EMBEDDED=true bash "$installer" --yes
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
    # Wachtwoord nu vragen, zodat de stille run niet op sudo blijft hangen.
    if command -v sudo >/dev/null 2>&1 && ! sudo -n true 2>/dev/null; then
        live_clear
        sudo -v || return 1
    fi
    prepare_aur
    run_quiet "$helper" "$helper" "${flags[@]}" || rc=$?
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
    if $UI; then
        live_clear
        printf '\n  %s%s%s %s100%%%s  %sKlaar%s\n' "$C_GREEN" "$(bar 1 1 14)" "$C_RESET" "$C_BOLD" "$C_RESET" "$C_BOLD" "$C_RESET"
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
    if [[ $code -eq 0 ]]; then
        log "Alle beschikbare updatebronnen zijn verwerkt."
    else
        log "Minstens één updatebron eindigde met een fout (code $code)."
    fi
    [[ -n "$LOG_FILE" ]] && log "${C_DIM}Log: $LOG_FILE${C_RESET}"
    echo
    live_clear
    read -r -p "Druk Enter om te sluiten..." _
}

# Eén update tegelijk. Twee runs naast elkaar (terminal plus het venster uit
# Instellingen) wachten op elkaars sudo, git en installer.
LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/kingstra-update.lock"
if command -v flock >/dev/null 2>&1 && exec 9>"$LOCK_FILE"; then
    if ! flock -n 9; then
        echo
        echo "  Er draait al een kingstra update (in een ander venster of een gestopte terminal)."
        echo "  Maak die eerst af of sluit hem. Vastgelopen? pkill -f package_upgrade.sh"
        echo
        if [[ -t 0 ]]; then read -r -p "Druk Enter om te sluiten..." _ || true; fi
        exit 1
    fi
fi

init_log

if $UI; then
    printf '\n  %sKingstra Update Runner%s  %syay %s Flatpak %s kingstra-dots%s\n' \
        "$C_BOLD" "$C_RESET" "$C_DIM" "$G_DOT" "$G_DOT" "$C_RESET"
else
    echo "=============================================="
    echo " Kingstra Update Runner"
    echo " yay · Flatpak · kingstra-dots"
    echo "=============================================="
fi
to_log "Gestart: $(date '+%Y-%m-%d %H:%M:%S')"

# Eerst de dotfiles ophalen en dan met de nieuwe updater verder. Anders
# draaien Arch/AUR, configbestanden en de controle nog met de code van vóór
# de update, en werken fixes pas bij de keer daarna.
if [[ -z "${KINGSTRA_UPDATE_REEXEC:-}" ]]; then
    self_before="$(git -C "$(resolve_dotfiles_repo 2>/dev/null || echo /nonexistent)" rev-parse HEAD 2>/dev/null || true)"
    live "Updater bijwerken"
    # Stil: wat er gebeurt staat in het log en komt bij Dotfiles terug.
    if [[ -n "$self_before" ]] && update_dotfiles >/dev/null; then
        self_after="$(git -C "$DOTFILES_REPO" rev-parse HEAD 2>/dev/null || true)"
        live_clear
        if [[ -n "$self_after" && "$self_after" != "$self_before" && -f "$SELF" ]]; then
            log "Dotfiles bijgewerkt (${self_before:0:7} → ${self_after:0:7}); verder met de nieuwe updater."
            export KINGSTRA_UPDATE_REEXEC="$self_before" KINGSTRA_UPDATE_LOG="$LOG_FILE"
            exec bash "$SELF" "${ORIG_ARGS[@]+"${ORIG_ARGS[@]}"}"
        fi
    fi
    DOTFILES_REPO=""
elif [[ "$KINGSTRA_UPDATE_REEXEC" =~ ^[0-9a-f]{7,}$ ]]; then
    to_log "Opnieuw gestart na dotfiles-update vanaf $KINGSTRA_UPDATE_REEXEC"
fi

section "Arch-nieuws"
if ! check_arch_news; then
    [[ -n "$LOG_FILE" ]] && log "Log: $LOG_FILE"
    live_clear
    read -r -p "Druk Enter om te sluiten..." _
    exit 0
fi

section "Wat er bijwerkt"
preview_updates
if $UI && ! $INTERACTIVE && (( REPO_COUNT + AUR_COUNT + FLATPAK_COUNT > 0 )); then
    if ! ask_yes "Updates installeren?"; then
        log "Update op verzoek gestopt."
        finish 0
        exit 0
    fi
fi

section "Terugzetpunt"
make_restore_point

section "Arch/AUR"
arch_exit=0
arch_since="$(date '+%Y-%m-%dT%H:%M:%S')"
update_arch || arch_exit=$?
if ! verify_arch "$arch_since" "$arch_exit"; then
    [[ $arch_exit -eq 0 ]] && arch_exit=1
fi
[[ $arch_exit -eq 0 ]] || overall_exit=$arch_exit

section "Flatpak"
flatpak_exit=0
if command -v flatpak >/dev/null 2>&1; then
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

section "Dotfiles"
dotfiles_update_exit=0
update_dotfiles || dotfiles_update_exit=$?
if [[ "${KINGSTRA_UPDATE_REEXEC:-}" =~ ^[0-9a-f]{7,}$ && -n "$DOTFILES_REPO" ]]; then
    log "Aan het begin opgehaald: ${KINGSTRA_UPDATE_REEXEC:0:7} → $(git -C "$DOTFILES_REPO" rev-parse --short HEAD 2>/dev/null)."
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
else
    result ok "Dotfiles bijgewerkt."
fi

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
"$COUNT_SCRIPT" --refresh >/dev/null 2>&1 || true

finish "$overall_exit"
exit "$overall_exit"
